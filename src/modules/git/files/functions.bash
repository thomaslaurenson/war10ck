# function: w_git_bump_submodule
#
# Move one submodule to a newer commit, after confirming at the prompt. With no
# ref the submodule follows the branch named in .gitmodules; with one it is
# fetched and checked out at exactly that tag, commit or branch.
#
# Arguments:
#   $1 - path to the submodule, as registered in .gitmodules
#   $2 - optional tag, commit or branch to use instead of the tracked branch
# Returns:
#   1 when the path is missing, the shell is not inside a repository, or the
#   path is not a registered submodule
w_git_bump_submodule() {
  local sub_path=$1
  local target_ref=$2
  local reply

  if [[ -z "${sub_path}" ]]; then
    printf 'Usage: w_git_bump_submodule <path/to/submodule> [tag/commit/branch]\n' >&2
    return 1
  fi

  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    printf '[!] Not inside a git repository\n' >&2
    return 1
  fi

  if ! git submodule status "${sub_path}" > /dev/null 2>&1; then
    printf "[!] '%s' is not a registered submodule\n" "${sub_path}" >&2
    return 1
  fi

  read -rp "[?] Bump ${sub_path}? (y/N) " reply
  case "${reply}" in
    [yY]*)
      printf '[*] Initializing %s...\n' "${sub_path}"
      git submodule update --init "${sub_path}"

      if [[ -z "${target_ref}" ]]; then
        printf '[*] Updating to the latest remote commit...\n'
        # Updates to the latest commit of the branch tracked in .gitmodules
        git submodule update --remote "${sub_path}"
      else
        printf '[*] Fetching and checking out specific ref: %s...\n' "${target_ref}"
        (cd "${sub_path}" && git fetch --all --tags --prune && git checkout "${target_ref}")
      fi
      printf '[*] Successfully bumped %s!\n' "${sub_path}"
      ;;
    *)
      printf '[*] Skipping %s...\n' "${sub_path}"
      ;;
  esac
}

# function: w_git_tag
#
# Create a signed vX.Y.Z tag on the checked out branch and push it to origin,
# showing the repository's state and confirming before either step.
#
# Returns:
#   1 when the shell is not inside a repository, HEAD is detached, the version
#   is empty, the tag already exists, or the tag could not be created or pushed
w_git_tag() {
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    printf '[!] Not inside a git repository\n' >&2
    return 1
  fi

  # Block on detached HEAD - a tag should be rooted to a named branch
  local branch
  if ! branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)"; then
    printf '[!] Detached HEAD - check out a branch before tagging\n' >&2
    return 1
  fi

  local repo_name remote="origin" remote_url latest_tag
  repo_name="$(basename "$(git rev-parse --show-toplevel)")"
  remote_url="$(git remote get-url "${remote}" 2>/dev/null || true)"
  latest_tag="$(git tag --sort=-v:refname 2>/dev/null | head -n 1)"

  printf '[*] Repository : %s\n' "${repo_name}"
  printf '[*] Branch     : %s\n' "${branch}"
  printf '[*] Remote     : %s\n' "${remote}"
  if [[ -n "${remote_url}" ]]; then
    printf '[*] Remote URL : %s\n' "${remote_url}"
  fi
  printf '[*] Latest tag : %s\n' "${latest_tag:-<none>}"
  printf '\n'

  # Warn on dirty tracked files (modified/staged); untracked files are ignored
  local dirty_confirm
  if ! git diff --quiet || ! git diff --cached --quiet; then
    printf '[!] Working tree is dirty:\n' >&2
    git status --short --untracked-files=no
    printf '\n'
    read -rp "[?] Continue with tag anyway? (y/N) " dirty_confirm
    case "${dirty_confirm}" in
      y|Y) ;;
      *)
        printf '[*] Aborted\n'
        return 0
        ;;
    esac
    printf '\n'
  fi

  local version
  read -rp "[?] Enter new version (without 'v' prefix): " version
  if [[ -z "${version}" ]]; then
    printf '[!] Version cannot be empty\n' >&2
    return 1
  fi

  local tag="v${version}"
  if git rev-parse "${tag}" > /dev/null 2>&1; then
    printf "[!] Tag '%s' already exists\n" "${tag}" >&2
    return 1
  fi

  printf '\n'
  printf '[*] About to create and push tag:\n'
  printf '    Tag        : %s\n' "${tag}"
  printf '    Repository : %s\n' "${repo_name}"
  printf '    Branch     : %s\n' "${branch}"
  if [[ -n "${latest_tag}" ]]; then
    printf '    Previous   : %s\n' "${latest_tag}"
  fi
  printf '\n'

  local confirm
  read -rp "[?] Proceed with tagging and push? (y/N) " confirm
  case "${confirm}" in
    y|Y) ;;
    *)
      printf '[*] Aborted\n'
      return 0
      ;;
  esac

  if ! git tag -s "${tag}" -m "Release ${tag}"; then
    printf "[!] Failed to create tag '%s'\n" "${tag}" >&2
    return 1
  fi

  if ! git push "${remote}" "${tag}"; then
    printf "[!] Push failed - tag '%s' exists locally but was not pushed\n" "${tag}" >&2
    printf '[!] To retry: git push %s %s\n' "${remote}" "${tag}" >&2
    return 1
  fi

  printf "[*] Tag '%s' created and pushed successfully\n" "${tag}"
}

# function: w_git_repository_properties
#
# Report the state of every git repository directly under a directory, which is
# the layout ~/repos/<org> has after an organisation is cloned.
#
# Needs nothing but git. The GitHub CLI and jq are not used here and no GitHub
# API call is made, so nothing this function does counts against an API rate
# limit. Each repository costs one fetch against its own origin.
#
# Every git call goes through -C rather than changing directory. An earlier
# version cd'd into each repository and never came back, so with a relative
# target the paths the glob produced stopped resolving after the first
# repository and every later one was silently skipped.
#
# Arguments:
#   $1 - directory holding the repositories, required
#   --no-fetch, --branches, --debug, --help - as described by --help
# Outputs:
#   a table on stdout, one row per repository; warnings on stderr
# Returns:
#   1 on an unknown option, a missing or non-directory target, or a target
#   holding no repositories
w_git_repository_properties() {
  local target="" fetch="yes" list_branches="no" debug="no"

  while (( $# > 0 )); do
    case "$1" in
      --help|-h|help)
        printf '%s\n' \
          'Usage: w_git_repository_properties DIR [--no-fetch] [--branches] [--debug]' \
          '' \
          'Report branch, ahead, behind, dirty state and unmerged branch count for' \
          'every git repository directly under DIR, such as ~/repos/<org>.' \
          '' \
          'Options:' \
          '  --no-fetch   Report against whatever each repository last fetched' \
          '  --branches   List the unmerged branch names beneath the table' \
          '  --debug      Print why a fetch failed instead of only naming the repo' \
          '' \
          'Ahead and behind are counted against the upstream of the checked out' \
          'branch; a dash in both means the branch tracks nothing. Unmerged counts' \
          'the other local branches holding commits the default branch does not.' \
          '' \
          'Fetches run with ssh batch mode on, so a repository whose key is not' \
          'loaded in the agent is reported as a failure rather than prompting.'
        return 0
        ;;
      --no-fetch) fetch="no" ;;
      --branches) list_branches="yes" ;;
      --debug) debug="yes" ;;
      -*)
        printf 'w_git_repository_properties: unknown option: %s\n' "$1" >&2
        return 1
        ;;
      *) target=$1 ;;
    esac
    shift
  done

  # Required rather than defaulting to the working directory. The default
  # invited being run from inside a repository, where the detection below
  # matched every subdirectory and reported the same repository several times
  # over, once per folder, which reads as several repositories in one state.
  if [[ -z "${target}" ]]; then
    printf 'w_git_repository_properties: a directory is required, try --help\n' >&2
    return 1
  fi

  if [[ ! -d "${target}" ]]; then
    printf 'w_git_repository_properties: not a directory: %s\n' "${target}" >&2
    return 1
  fi

  # A directory counts only when it is the top of its own working tree.
  # rev-parse --git-dir alone succeeds anywhere inside a repository, so
  # scanning one would list src, test and every other folder as a repository
  # in its own right, each showing the parent's state.
  #
  # --show-prefix answers that directly: it is empty at the top of a working
  # tree and names the subpath anywhere below it. Comparing --show-toplevel
  # against the resolved directory does the same job in principle, but it has
  # to canonicalise both sides and so turns on how symlinks along the path
  # happen to resolve. Worktrees and submodules each report themselves and
  # are kept either way.
  local -a repos=()
  local dir prefix
  for dir in "${target}"/*/; do
    dir=${dir%/}
    [[ -d "${dir}" ]] || continue
    prefix=$(git -C "${dir}" rev-parse --show-prefix 2>/dev/null) || continue
    if [[ -z "${prefix}" ]]; then
      repos+=("${dir}")
    fi
  done

  if (( ${#repos[@]} == 0 )); then
    printf '[!] No git repositories under %s\n' "${target}" >&2
    return 1
  fi

  # A repository with no origin has nothing to fetch and nothing to be ahead
  # of, so it is separated here rather than counted as a fetch failure.
  local -a fetchable=() remoteless=()
  for dir in "${repos[@]}"; do
    if git -C "${dir}" remote get-url origin > /dev/null 2>&1; then
      fetchable+=("${dir}")
    else
      remoteless+=("$(basename "${dir}")")
    fi
  done

  local workdir
  workdir=$(mktemp -d)

  local i max_jobs=8
  if [[ "${fetch}" == "yes" && ${#fetchable[@]} -gt 0 ]]; then
    printf '[*] Fetching %s repositories...\n' "${#fetchable[@]}"
    # The whole parallel section runs in a subshell because an interactive
    # shell announces every background job it starts and every one that
    # stops, and bash turns that reporting off inside a subshell.
    (
      # Batch mode and no terminal prompt together mean a fetch needing
      # credentials fails immediately. Without them ssh reads the
      # passphrase straight from the terminal, and a background job doing
      # that takes SIGTTIN and stops, which is what left jobs suspended
      # and the table waiting on them.
      export GIT_TERMINAL_PROMPT=0
      export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -oBatchMode=yes"

      for i in "${!fetchable[@]}"; do
        # --prune so a branch deleted on the remote stops being counted
        # here. Output is kept rather than discarded so --debug has
        # something to show, and a failure is recorded because the
        # counts below would otherwise present a stale cache as fact.
        git -C "${fetchable[i]}" fetch --quiet --prune origin \
          > "${workdir}/out.${i}" 2>&1 < /dev/null \
          || printf '%s\n' "${fetchable[i]}" > "${workdir}/fail.${i}" &
        if (( (i + 1) % max_jobs == 0 )); then
          wait
        fi
      done
      wait
    )
  fi

  local -a failed=()
  local f idx
  for f in "${workdir}"/fail.*; do
    [[ -f "${f}" ]] || continue
    idx=${f##*.}
    failed+=("$(basename "$(cat "${f}")")")
    if [[ "${debug}" == "yes" && -s "${workdir}/out.${idx}" ]]; then
      printf '[!] %s:\n' "$(basename "$(cat "${f}")")" >&2
      sed 's/^/    /' "${workdir}/out.${idx}" >&2
    fi
  done
  rm -rf "${workdir}"

  local width=10 name
  for dir in "${repos[@]}"; do
    name=$(basename "${dir}")
    (( ${#name} > width )) && width=${#name}
  done

  printf '%-*s  %-20s  %5s  %6s  %5s  %8s\n' \
    "${width}" "Repository" "Branch" "Ahead" "Behind" "Dirty" "Unmerged"
  printf '%-*s  %-20s  %5s  %6s  %5s  %8s\n' \
    "${width}" "----------" "------" "-----" "------" "-----" "--------"

  local branch ahead behind dirty base counts candidate
  local -a branches=() detail=()
  for dir in "${repos[@]}"; do
    name=$(basename "${dir}")

    if ! branch=$(git -C "${dir}" symbolic-ref --quiet --short HEAD 2>/dev/null); then
      branch="(detached)"
    fi

    # --porcelain counts untracked files as dirty too. Checking only the
    # diffs calls a repository clean while it holds work git has never seen.
    if [[ -n "$(git -C "${dir}" status --porcelain 2>/dev/null)" ]]; then
      dirty="yes"
    else
      dirty="no"
    fi

    # The left side of a three-dot range is the upstream's own commits,
    # which is how far behind HEAD is, and the right side is HEAD's own,
    # which is how far ahead. Reading them the other way round is what made
    # these two columns report each other's value.
    ahead="-"
    behind="-"
    if git -C "${dir}" rev-parse --abbrev-ref --symbolic-full-name '@{u}' > /dev/null 2>&1; then
      if counts=$(git -C "${dir}" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null) \
        && [[ -n "${counts}" ]]; then
        read -r behind ahead <<< "${counts}"
      fi
    fi

    # Counted against the remote's default branch rather than HEAD, so a
    # forgotten branch still shows while a different one is checked out.
    base=$(git -C "${dir}" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
    [[ -n "${base}" ]] || base=$(git -C "${dir}" rev-parse --abbrev-ref HEAD 2>/dev/null)

    # The checked out branch is dropped from the count. Its own unpushed
    # commits are what the ahead column already reports, and listing it
    # here as well reads as a second, separate problem.
    branches=()
    while IFS= read -r candidate; do
      if [[ -n "${candidate}" && "${candidate}" != "${branch}" ]]; then
        branches+=("${candidate}")
      fi
    done < <(git -C "${dir}" branch --no-merged "${base}" \
      --format='%(refname:short)' 2>/dev/null)

    printf '%-*s  %-20s  %5s  %6s  %5s  %8s\n' \
      "${width}" "${name}" "${branch}" "${ahead}" "${behind}" "${dirty}" "${#branches[@]}"

    if (( ${#branches[@]} > 0 )); then
      detail+=("${name}: ${branches[*]}")
    fi
  done

  if [[ "${list_branches}" == "yes" && ${#detail[@]} -gt 0 ]]; then
    printf '\n[*] Unmerged branches:\n'
    printf '    %s\n' "${detail[@]}"
  fi

  if (( ${#remoteless[@]} > 0 )); then
    printf '\n[*] No origin remote: %s\n' "${remoteless[*]}"
  fi

  if (( ${#failed[@]} > 0 )); then
    printf '\n[!] Fetch failed, ahead and behind may be stale: %s\n' "${failed[*]}" >&2
    [[ "${debug}" == "yes" ]] || printf '[*] Re-run with --debug to see why\n' >&2
  fi
}

# function: _w_git_disable_repo_feature
#
# Turn one repository feature off across every non-archived repository a GitHub
# user or organisation owns. The name is prompted for, and the repositories that
# have the feature on are listed and confirmed before any is edited. They are
# read through the GitHub CLI, so gh has to be authenticated as an account that
# can edit them.
#
# Arguments:
#   $1 - the field gh repo list reports the feature under, such as hasWikiEnabled
#   $2 - the gh repo edit flag that turns the feature on, such as enable-wiki
#   $3 - the feature as printed, such as wiki
# Outputs:
#   the repositories to change on stdout, then one line per repository changed;
#   warnings and errors on stderr
# Returns:
#   1 when the name is empty, the repositories could not be listed, or any
#   repository could not be changed
_w_git_disable_repo_feature() {
  local field=$1 flag=$2 label=$3

  # gh repo list reads an empty owner as the authenticated account, so an
  # accidental Enter would otherwise edit every repository that account owns.
  local target
  read -rp '[?] Enter GitHub user/org name: ' target
  if [[ -z "${target}" ]]; then
    printf '[!] Name cannot be empty\n' >&2
    return 1
  fi

  # gh stops at the limit without saying so, so reaching it is reported rather
  # than taken to be every repository the owner has.
  local limit=1000 repo_metadata
  if ! repo_metadata=$(gh repo list "${target}" --limit "${limit}" --no-archived \
    --json "nameWithOwner,${field}"); then
    printf '[!] Could not list repositories for %s\n' "${target}" >&2
    return 1
  fi

  local total
  total=$(jq 'length' <<< "${repo_metadata}")
  if (( total >= limit )); then
    printf '[!] Listing stopped at %s repositories, so any beyond it were not checked\n' \
      "${limit}" >&2
  fi

  local -a names=()
  readarray -t names < <(jq -r --arg field "${field}" \
    '.[] | select(.[$field]) | .nameWithOwner' <<< "${repo_metadata}")

  printf '[*] Repositories with %s on: %s of %s\n' "${label}" "${#names[@]}" "${total}"
  if (( ${#names[@]} == 0 )); then
    return 0
  fi

  printf '\n'
  local name
  for name in "${names[@]}"; do
    printf '    %s\n' "${name}"
  done
  printf '\n'

  local reply
  read -rp "[?] Disable ${label} in the repositories listed above? (y/N) " reply
  case "${reply}" in
    y|Y) ;;
    *)
      printf '[*] Aborted\n'
      return 0
      ;;
  esac

  # gh's stdout is dropped because, whenever it is a terminal, gh opens its
  # success line with a non-ASCII tick. Its stderr is kept, since that is where
  # the reason for a failed edit goes.
  local failures=0
  for name in "${names[@]}"; do
    if gh repo edit "${name}" "--${flag}=false" > /dev/null; then
      printf '[~] Disabled %s: %s\n' "${label}" "${name}"
    else
      printf '[!] Could not disable %s: %s\n' "${label}" "${name}" >&2
      failures=$((failures + 1))
    fi
  done

  if (( failures > 0 )); then
    printf '[!] Repositories not changed: %s of %s\n' "${failures}" "${#names[@]}" >&2
    return 1
  fi
}

# function: w_git_disable_project_for_user
#
# Turn the projects tab off across every non-archived repository a GitHub user
# or organisation owns, after listing the repositories that have it on and
# confirming at the prompt.
#
# Outputs:
#   the repositories to change on stdout, then one line per repository changed;
#   warnings and errors on stderr
# Returns:
#   1 when the name is empty, the repositories could not be listed, or any
#   repository could not be changed
w_git_disable_project_for_user() {
  _w_git_disable_repo_feature hasProjectsEnabled enable-projects projects
}

# function: w_git_disable_wiki_for_user
#
# Turn the wiki off across every non-archived repository a GitHub user or
# organisation owns, after listing the repositories that have it on and
# confirming at the prompt.
#
# Outputs:
#   the repositories to change on stdout, then one line per repository changed;
#   warnings and errors on stderr
# Returns:
#   1 when the name is empty, the repositories could not be listed, or any
#   repository could not be changed
w_git_disable_wiki_for_user() {
  _w_git_disable_repo_feature hasWikiEnabled enable-wiki wiki
}

# function: w_git_disable_discussions_for_user
#
# Turn discussions off across every non-archived repository a GitHub user or
# organisation owns, after listing the repositories that have them on and
# confirming at the prompt.
#
# Outputs:
#   the repositories to change on stdout, then one line per repository changed;
#   warnings and errors on stderr
# Returns:
#   1 when the name is empty, the repositories could not be listed, or any
#   repository could not be changed
w_git_disable_discussions_for_user() {
  _w_git_disable_repo_feature hasDiscussionsEnabled enable-discussions discussions
}

# function: _w_git_list_checked_repos
#
# List the repositories the check functions cover: every public, non-archived
# repository the named owners have, other than forks and profile repositories.
# A fork's description is usually its upstream's, and a profile repository
# only holds the README GitHub shows on the owner's page, so neither is a
# project of the owner's to describe or tag.
#
# Arguments:
#   $@ - one or more GitHub user or organisation names
# Outputs:
#   a JSON object on stdout holding repos, the repositories sorted by name and
#   each with nameWithOwner, description and repositoryTopics, and skipped,
#   the names of the profile repositories left out; warnings on stderr
# Returns:
#   1 when any owner's repositories could not be listed
_w_git_list_checked_repos() {
  # gh stops at the limit without saying so, so reaching it is reported rather
  # than taken to be every repository the owner has. --source leaves forks out
  # of the listing.
  local limit=1000 owner listing total
  local -a listings=()
  for owner in "$@"; do
    if ! listing=$(gh repo list "${owner}" --limit "${limit}" --no-archived \
      --source --visibility public \
      --json nameWithOwner,description,repositoryTopics); then
      printf '[!] Could not list repositories for %s\n' "${owner}" >&2
      return 1
    fi
    total=$(jq 'length' <<< "${listing}")
    if (( total >= limit )); then
      printf '[!] Listing %s stopped at %s repositories, %s\n' "${owner}" \
        "${limit}" 'so any beyond it were not checked' >&2
    fi
    listings+=("${listing}")
  done

  # unique_by sorts by name as well, and drops the repeats an owner named
  # twice would otherwise produce. A profile repository is the one GitHub
  # shows on the owner's page: a user's is named after the user and an
  # organisation's is .github.
  printf '%s\n' "${listings[@]}" | jq -s '
    def profile: .nameWithOwner | ascii_downcase | split("/")
      | .[1] == .[0] or .[1] == ".github";
    add | unique_by(.nameWithOwner | ascii_downcase)
    | {repos: map(select(profile | not)),
       skipped: map(select(profile) | .nameWithOwner)}'
}

# function: _w_git_print_problems
#
# Print what each failing repository needs, beneath a check function's table.
#
# Arguments:
#   $1 - the results, a JSON array of objects each holding name, problems (what
#        the repository needs) and detail (lines printed beneath the problems)
# Outputs:
#   one block per failing repository on stdout
_w_git_print_problems() {
  jq -r '.[] | select(.problems | length > 0)
    | "", "[!] \(.name)",
      (.problems[] | "    - \(.)"),
      (.detail[] | "      \(.)")' <<< "$1"
}

# function: _w_git_print_summary
#
# Close a check function's report with the profile repositories skipped and
# how many repositories passed.
#
# Arguments:
#   $1 - the results, as passed to _w_git_print_problems
#   $2 - the names of the profile repositories skipped, as a JSON array
# Outputs:
#   the summary on stdout
# Returns:
#   1 when any repository has a problem
_w_git_print_summary() {
  local skipped count failing
  skipped=$(jq -r 'join(" ")' <<< "$2")
  if [[ -n "${skipped}" ]]; then
    printf '\n[*] Skipped profile repositories: %s\n' "${skipped}"
  fi

  count=$(jq 'length' <<< "$1")
  failing=$(jq 'map(select(.problems | length > 0)) | length' <<< "$1")
  printf '\n[*] Repositories passing: %s of %s\n' \
    "$(( count - failing ))" "${count}"

  (( failing == 0 ))
}

# function: _w_git_site_projects
#
# Print the projects thomaslaurenson.com lists, read from the site's data file
# on its default branch. The published branch is read, rather than a local
# clone, because a clone can be ahead of or behind what the site shows.
#
# The file is JavaScript, not JSON, so it is read line by line rather than
# evaluated. That relies on the layout it has: each project an object literal
# with one property per line, each value a quoted string or a bare true or
# false, and each object closed by a line holding only "}" or "},". Anything
# else in the file, such as the social links, has no description and is
# skipped.
#
# Arguments:
#   $1 - repository holding the site, as owner/name
#   $2 - path of the data file within it
# Outputs:
#   one line per project on stdout: the GitHub repository as owner/name in
#   lower case, the archived flag, and the description, separated by tabs
# Returns:
#   1 when the file could not be fetched
_w_git_site_projects() {
  local site_repo=$1 site_path=$2 content

  if ! content=$(gh api -H 'Accept: application/vnd.github.raw' \
    "repos/${site_repo}/contents/${site_path}"); then
    return 1
  fi

  # \047 is a single quote, which this single-quoted program cannot hold. A
  # value loses its surrounding quotes and trailing comma, and a quote escaped
  # inside it is unescaped, so the description compares equal to GitHub's.
  awk '
    function value(line,    q) {
      sub(/^[^:]*:[[:space:]]*/, "", line)
      sub(/,?[[:space:]]*$/, "", line)
      q = substr(line, 1, 1)
      if (q == "\047" || q == "\"") {
        line = substr(line, 2, length(line) - 2)
        gsub("\\\\" q, q, line)
      }
      return line
    }
    function reset() { desc = ""; repo = ""; archived = "false" }
    /^[[:space:]]*name:/ { reset() }
    /^[[:space:]]*description:/ { desc = value($0) }
    /^[[:space:]]*github:/ {
      repo = tolower(value($0))
      sub(/^https?:\/\/(www\.)?github\.com\//, "", repo)
      sub(/(\.git)?\/?$/, "", repo)
    }
    /^[[:space:]]*archived:/ { archived = value($0) }
    /^[[:space:]]*},?[[:space:]]*$/ {
      if (desc != "" && repo != "") {
        printf "%s\t%s\t%s\n", repo, archived, desc
      }
      reset()
    }
  ' <<< "${content}"
}

# function: w_git_check_descriptions
#
# Check the description of every public, non-archived repository the named
# GitHub users or organisations own, forks and profile repositories aside. Each
# must fall within the length limits, and one thomaslaurenson.com lists must
# match the site's word for word. A project the site shows as active must also
# be among the repositories checked, since the site links to it.
#
# The limits count characters, not words, because they exist to make the
# portfolio cards on the site render alike. A card's height follows how many
# lines its description wraps to, and that turns on characters: 130 to 160 is
# three lines at the desktop width. Words are reported alongside for reference.
#
# Nothing is edited, on GitHub or on the site. Both are read through the
# GitHub CLI, so gh has to be authenticated.
#
# Arguments:
#   $@ - one or more GitHub user or organisation names, and the options
#        described by --help
# Outputs:
#   a table on stdout, one row per repository, then what each failing
#   repository needs; warnings and errors on stderr
# Returns:
#   1 on a bad option or no owner, when a listing or the site's data could
#   not be read, or when any repository or site project fails the check
w_git_check_descriptions() {
  local min_chars=130 max_chars=160 site="yes"
  local site_repo="thomaslaurenson/thomaslaurenson.github.io"
  local site_path="src/data/constants.js"
  local -a owners=()

  while (( $# > 0 )); do
    case "$1" in
      --help|-h|help)
        printf '%s\n' \
          'Usage: w_git_check_descriptions OWNER... [options]' \
          '' \
          'Check that the description of every public, non-archived repository' \
          'OWNER has is within the length limits, and that the projects' \
          'thomaslaurenson.com lists have the same description as the site.' \
          'Forks and profile repositories (OWNER/OWNER, OWNER/.github) are' \
          'skipped.' \
          '' \
          'Options:' \
          '  --min-chars N   Shortest description allowed (default 130)' \
          '  --max-chars N   Longest description allowed (default 160)' \
          '  --no-site       Skip the comparison with the site' \
          '' \
          'The default limits keep a description to three lines on a site card.' \
          "The site's descriptions are read from ${site_path} on the" \
          "default branch of ${site_repo}."
        return 0
        ;;
      --min-chars|--max-chars)
        if [[ ! "${2:-}" =~ ^[0-9]+$ ]]; then
          printf 'w_git_check_descriptions: %s needs a number\n' "$1" >&2
          return 1
        fi
        if [[ "$1" == "--min-chars" ]]; then
          min_chars=$2
        else
          max_chars=$2
        fi
        shift
        ;;
      --no-site) site="no" ;;
      -*)
        printf 'w_git_check_descriptions: unknown option: %s\n' "$1" >&2
        return 1
        ;;
      *) owners+=("$1") ;;
    esac
    shift
  done

  # Required rather than defaulting to the authenticated account, which is
  # what gh repo list does with no owner, so the report always says whose
  # repositories it covers.
  if (( ${#owners[@]} == 0 )); then
    printf 'w_git_check_descriptions: an owner is required, try --help\n' >&2
    return 1
  fi

  if (( min_chars > max_chars )); then
    printf 'w_git_check_descriptions: --min-chars is above --max-chars\n' >&2
    return 1
  fi

  local listing
  if ! listing=$(_w_git_list_checked_repos "${owners[@]}"); then
    return 1
  fi

  local projects='[]' site_lines
  if [[ "${site}" == "yes" ]]; then
    if ! site_lines=$(_w_git_site_projects "${site_repo}" "${site_path}"); then
      printf '[!] Could not read %s from %s\n' "${site_path}" "${site_repo}" >&2
      printf '[*] Re-run with --no-site to check the repositories alone\n' >&2
      return 1
    fi
    # An empty result means the file's layout no longer matches what the
    # reader expects. Carrying on would compare against nothing and pass
    # every repository the site lists.
    if [[ -z "${site_lines}" ]]; then
      printf '[!] Found no projects in %s, so its layout may have changed\n' \
        "${site_path}" >&2
      return 1
    fi
    projects=$(jq -R -s 'split("\n") | map(select(length > 0)
      | split("\t")
      | {repo: .[0], archived: (.[1] == "true"),
         description: (.[2:] | join("\t"))})' <<< "${site_lines}")
  fi

  # Both descriptions are kept under a mismatch so the fix can be made
  # without opening either.
  local results
  results=$(jq --argjson projects "${projects}" --argjson min "${min_chars}" \
    --argjson max "${max_chars}" '
    ($projects | map({key: .repo, value: .description}) | from_entries)
      as $site
    | .repos | map(
        (.description // "") as $text
        | ($text | length) as $chars
        | $site[.nameWithOwner | ascii_downcase] as $listed
        | (if $listed == null then "-"
           elif $listed == $text then "match"
           else "differs" end) as $state
        | {
            name: .nameWithOwner,
            chars: $chars,
            words: ([$text | scan("\\S+")] | length),
            site: $state,
            problems: [
              if $text == "" then "no description"
              elif $chars < $min or $chars > $max then
                "description is \($chars) characters, needs \($min) to \($max)"
              else empty end,
              if $state == "differs" then "description differs from the site"
              else empty end
            ],
            detail: (if $state == "differs" then [
                "github: \(if $text == "" then "(none)" else $text end)",
                "site:   \($listed)"
              ] else [] end)
          }
      )' <<< "${listing}")

  # Only the owners checked are held to this. A project under any other owner
  # was not listed, so its absence says nothing.
  local -a absent=()
  readarray -t absent < <(jq -r --argjson projects "${projects}" '
    (.repos | map(.nameWithOwner | ascii_downcase)) as $listed
    | ($ARGS.positional | map(ascii_downcase)) as $owners
    | $projects[]
    | select(.archived | not)
    | select(.repo | split("/")[0] | IN($owners[]))
    | select(.repo | IN($listed[]) | not)
    | .repo' --args "${owners[@]}" <<< "${listing}")

  local width
  width=$(jq '[.[].name | length, 10] | max' <<< "${results}")

  printf '%-*s  %5s  %5s  %-7s  %s\n' \
    "${width}" "Repository" "Chars" "Words" "Site" "Result"
  printf '%-*s  %5s  %5s  %-7s  %s\n' \
    "${width}" "----------" "-----" "-----" "----" "------"

  local name chars words state result
  while IFS=$'\t' read -r name chars words state result; do
    printf '%-*s  %5s  %5s  %-7s  %s\n' \
      "${width}" "${name}" "${chars}" "${words}" "${state}" "${result}"
  done < <(jq -r '.[] | [.name, .chars, .words, .site,
      (if (.problems | length) == 0 then "pass" else "fail" end)]
    | @tsv' <<< "${results}")

  _w_git_print_problems "${results}"

  if (( ${#absent[@]} > 0 )); then
    printf '\n[!] On the site as active, but not a public, active repository:\n'
    printf '    %s\n' "${absent[@]}"
  fi

  local status=0
  _w_git_print_summary "${results}" "$(jq '.skipped' <<< "${listing}")" \
    || status=1
  if (( ${#absent[@]} > 0 )); then
    status=1
  fi
  return "${status}"
}

# function: w_git_check_topics
#
# Check that every public, non-archived repository the named GitHub users or
# organisations own, forks and profile repositories aside, is tagged with
# enough topics. The topics each repository has are listed so they can be
# compared across repositories.
#
# Nothing is edited. Repositories are read through the GitHub CLI, so gh has
# to be authenticated.
#
# Arguments:
#   $@ - one or more GitHub user or organisation names, and the options
#        described by --help
# Outputs:
#   a table on stdout, one row per repository, then what each failing
#   repository needs; warnings and errors on stderr
# Returns:
#   1 on a bad option or no owner, when a listing could not be read, or when
#   any repository has too few topics
w_git_check_topics() {
  local min_topics=3
  local -a owners=()

  while (( $# > 0 )); do
    case "$1" in
      --help|-h|help)
        printf '%s\n' \
          'Usage: w_git_check_topics OWNER... [options]' \
          '' \
          'Check that every public, non-archived repository OWNER has is' \
          'tagged with enough topics, and list the topics each one has.' \
          'Forks and profile repositories (OWNER/OWNER, OWNER/.github) are' \
          'skipped.' \
          '' \
          'Options:' \
          '  --min-topics N  Fewest topics allowed (default 3)'
        return 0
        ;;
      --min-topics)
        if [[ ! "${2:-}" =~ ^[0-9]+$ ]]; then
          printf 'w_git_check_topics: %s needs a number\n' "$1" >&2
          return 1
        fi
        min_topics=$2
        shift
        ;;
      -*)
        printf 'w_git_check_topics: unknown option: %s\n' "$1" >&2
        return 1
        ;;
      *) owners+=("$1") ;;
    esac
    shift
  done

  if (( ${#owners[@]} == 0 )); then
    printf 'w_git_check_topics: an owner is required, try --help\n' >&2
    return 1
  fi

  local listing
  if ! listing=$(_w_git_list_checked_repos "${owners[@]}"); then
    return 1
  fi

  # gh reports a repository with no topics as null rather than an empty list.
  local results
  results=$(jq --argjson min "${min_topics}" '.repos | map(
      [(.repositoryTopics // [])[].name] as $topics
      | {
          name: .nameWithOwner,
          count: ($topics | length),
          topics: (if $topics == [] then "-" else $topics | join(", ") end),
          problems: [
            if ($topics | length) < $min then
              "needs at least \($min) topics, has \($topics | length)"
            else empty end
          ],
          detail: []
        }
    )' <<< "${listing}")

  local width
  width=$(jq '[.[].name | length, 10] | max' <<< "${results}")

  printf '%-*s  %6s  %-6s  %s\n' \
    "${width}" "Repository" "Topics" "Result" "Names"
  printf '%-*s  %6s  %-6s  %s\n' \
    "${width}" "----------" "------" "------" "-----"

  local name count result topics
  while IFS=$'\t' read -r name count result topics; do
    printf '%-*s  %6s  %-6s  %s\n' \
      "${width}" "${name}" "${count}" "${result}" "${topics}"
  done < <(jq -r '.[] | [.name, .count,
      (if (.problems | length) == 0 then "pass" else "fail" end), .topics]
    | @tsv' <<< "${results}")

  _w_git_print_problems "${results}"
  _w_git_print_summary "${results}" "$(jq '.skipped' <<< "${listing}")"
}
