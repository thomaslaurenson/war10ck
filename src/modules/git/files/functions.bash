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

# function: w_git_disable_project_for_user
#
# Turn the projects tab off across every non-archived repository a GitHub user
# or organisation owns, prompting for the name. Repositories are read through
# the GitHub CLI, so gh has to be authenticated as an account that can edit
# them.
#
# Outputs:
#   one line per repository on stdout, naming it and whether projects were on
# Returns:
#   1 when the repositories could not be listed
w_git_disable_project_for_user() {
  local target repo_metadata json enabled name

  printf '[?] Enter GitHub user/org name: '
  read -r target

  if ! repo_metadata=$(gh repo list "${target}" -L 100 --no-archived \
    --json nameWithOwner,hasProjectsEnabled); then
    printf 'w_git_disable_project_for_user: could not list repositories for %s\n' \
      "${target}" >&2
    return 1
  fi

  # Process substitution rather than a pipe, which would run the loop in a
  # subshell and lose every assignment it makes.
  while IFS= read -r json; do
    enabled=$(jq -r '.hasProjectsEnabled' <<< "${json}")
    name=$(jq -r '.nameWithOwner' <<< "${json}")
    printf '[*] %s | %s\n' "${name}" "${enabled}"
    if [[ "${enabled}" == "true" ]]; then
      printf '[~] Disabling repository project...\n'
      gh repo edit "${name}" --enable-projects=false
    fi
  done < <(jq -c '.[]' <<< "${repo_metadata}")
}

# function: w_git_disable_wiki_for_user
#
# Turn the wiki off across every non-archived repository a GitHub user or
# organisation owns, prompting for the name. Repositories are read through the
# GitHub CLI, so gh has to be authenticated as an account that can edit them.
#
# Outputs:
#   one line per repository on stdout, naming it and whether the wiki was on
# Returns:
#   1 when the repositories could not be listed
w_git_disable_wiki_for_user() {
  local target repo_metadata json enabled name

  printf '[?] Enter GitHub user/org name: '
  read -r target

  if ! repo_metadata=$(gh repo list "${target}" -L 100 --no-archived \
    --json nameWithOwner,hasWikiEnabled); then
    printf 'w_git_disable_wiki_for_user: could not list repositories for %s\n' \
      "${target}" >&2
    return 1
  fi

  while IFS= read -r json; do
    enabled=$(jq -r '.hasWikiEnabled' <<< "${json}")
    name=$(jq -r '.nameWithOwner' <<< "${json}")
    printf '[*] %s | %s\n' "${name}" "${enabled}"
    if [[ "${enabled}" == "true" ]]; then
      printf '[~] Disabling repository wiki...\n'
      gh repo edit "${name}" --enable-wiki=false
    fi
  done < <(jq -c '.[]' <<< "${repo_metadata}")
}
