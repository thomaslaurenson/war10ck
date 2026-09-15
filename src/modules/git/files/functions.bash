# function: w_git_bump_submodule
w_git_bump_submodule() {
    local sub_path=$1
    local target_ref=$2

    if [[ -z "$sub_path" ]]; then
        echo "Usage: w_git_bump_submodule <path/to/submodule> [tag/commit/branch]"
        return 1
    fi

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "[!] Not inside a git repository"
        return 1
    fi

    if ! git submodule status "$sub_path" >/dev/null 2>&1; then
        echo "[!] '$sub_path' is not a registered submodule"
        return 1
    fi

    read -rp "[*] Bump $sub_path? (y/N) " yn
    case "$yn" in
        [yY]* )
            echo "[*] Initializing $sub_path..."
            git submodule update --init "$sub_path"

            if [[ -z "$target_ref" ]]; then
                echo "[*] Updating to the latest remote commit..."
                # Updates to the latest commit of the branch tracked in .gitmodules
                git submodule update --remote "$sub_path"
            else
                echo "[*] Fetching and checking out specific ref: $target_ref..."
                (cd "$sub_path" && git fetch --all --tags --prune && git checkout "$target_ref")
            fi
            echo "[*] Successfully bumped $sub_path!"
            ;;
        * )
            echo "[*] Skipping $sub_path..."
            ;;
    esac
}

# function: w_git_tag
w_git_tag() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "[!] Not inside a git repository"
        return 1
    fi
    # Block on detached HEAD - a tag should be rooted to a named branch
    local branch
    if ! branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)"; then
        echo "[!] Detached HEAD - check out a branch before tagging"
        return 1
    fi
    local repo_name
    repo_name="$(basename "$(git rev-parse --show-toplevel)")"
    local remote="origin"
    local remote_url
    remote_url="$(git remote get-url "$remote" 2>/dev/null || true)"
    local latest_tag
    latest_tag="$(git tag --sort=-v:refname 2>/dev/null | head -n 1)"
    echo "[*] Repository : $repo_name"
    echo "[*] Branch     : $branch"
    echo "[*] Remote     : $remote"
    [ -n "$remote_url" ] && echo "[*] Remote URL : $remote_url"
    [ -n "$latest_tag" ] && echo "[*] Latest tag : $latest_tag" || echo "[*] Latest tag : <none>"
    echo
    # Warn on dirty tracked files (modified/staged); untracked files are ignored
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "[!] Working tree is dirty:"
        git status --short --untracked-files=no
        echo
        read -rp "[?] Continue with tag anyway? (y/N) " dirty_confirm
        case "$dirty_confirm" in
            y|Y) ;;
            *)
                echo "[*] Aborted"
                return 0
                ;;
        esac
        echo
    fi
    read -rp "[*] Enter new version (without 'v' prefix): " version
    if [[ -z "$version" ]]; then
        echo "[!] Version cannot be empty"
        return 1
    fi
    local tag="v$version"
    if git rev-parse "$tag" >/dev/null 2>&1; then
        echo "[!] Tag '$tag' already exists"
        return 1
    fi
    echo
    echo "[*] About to create and push tag:"
    echo "    Tag        : $tag"
    echo "    Repository : $repo_name"
    echo "    Branch     : $branch"
    [ -n "$latest_tag" ] && echo "    Previous   : $latest_tag"
    echo
    read -rp "[?] Proceed with tagging and push? (y/N) " confirm
    case "$confirm" in
        y|Y) ;;
        *)
            echo "[*] Aborted"
            return 0
            ;;
    esac
    if ! git tag -s "$tag" -m "Release $tag"; then
        echo "[!] Failed to create tag '$tag'"
        return 1
    fi
    if ! git push "$remote" "$tag"; then
        echo "[!] Push failed - tag '$tag' exists locally but was not pushed"
        echo "[!] To retry: git push $remote $tag"
        return 1
    fi
    echo "Tag '$tag' created and pushed successfully"
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
            --no-fetch)  fetch="no" ;;
            --branches)  list_branches="yes" ;;
            --debug)     debug="yes" ;;
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
    if [[ -z "$target" ]]; then
        printf 'w_git_repository_properties: a directory is required, try --help\n' >&2
        return 1
    fi

    if [[ ! -d "$target" ]]; then
        printf 'w_git_repository_properties: not a directory: %s\n' "$target" >&2
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
    for dir in "$target"/*/; do
        dir=${dir%/}
        [[ -d "$dir" ]] || continue
        prefix=$(git -C "$dir" rev-parse --show-prefix 2>/dev/null) || continue
        if [[ -z "$prefix" ]]; then
            repos+=("$dir")
        fi
    done

    if (( ${#repos[@]} == 0 )); then
        printf '[!] No git repositories under %s\n' "$target" >&2
        return 1
    fi

    # A repository with no origin has nothing to fetch and nothing to be ahead
    # of, so it is separated here rather than counted as a fetch failure.
    local -a fetchable=() remoteless=()
    for dir in "${repos[@]}"; do
        if git -C "$dir" remote get-url origin > /dev/null 2>&1; then
            fetchable+=("$dir")
        else
            remoteless+=("$(basename "$dir")")
        fi
    done

    local workdir
    workdir=$(mktemp -d)

    local i max_jobs=8
    if [[ "$fetch" == "yes" && ${#fetchable[@]} -gt 0 ]]; then
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
                    > "$workdir/out.$i" 2>&1 < /dev/null \
                    || printf '%s\n' "${fetchable[i]}" > "$workdir/fail.$i" &
                if (( (i + 1) % max_jobs == 0 )); then
                    wait
                fi
            done
            wait
        )
    fi

    local -a failed=()
    local f idx
    for f in "$workdir"/fail.*; do
        [[ -f "$f" ]] || continue
        idx=${f##*.}
        failed+=("$(basename "$(cat "$f")")")
        if [[ "$debug" == "yes" && -s "$workdir/out.$idx" ]]; then
            printf '[!] %s:\n' "$(basename "$(cat "$f")")" >&2
            sed 's/^/    /' "$workdir/out.$idx" >&2
        fi
    done
    rm -rf "$workdir"

    local width=10 name
    for dir in "${repos[@]}"; do
        name=$(basename "$dir")
        (( ${#name} > width )) && width=${#name}
    done

    printf '%-*s  %-20s  %5s  %6s  %5s  %8s\n' \
        "$width" "Repository" "Branch" "Ahead" "Behind" "Dirty" "Unmerged"
    printf '%-*s  %-20s  %5s  %6s  %5s  %8s\n' \
        "$width" "----------" "------" "-----" "------" "-----" "--------"

    local branch ahead behind dirty base counts candidate
    local -a branches=() detail=()
    for dir in "${repos[@]}"; do
        name=$(basename "$dir")

        if ! branch=$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null); then
            branch="(detached)"
        fi

        # --porcelain counts untracked files as dirty too. Checking only the
        # diffs calls a repository clean while it holds work git has never seen.
        if [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]; then
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
        if git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' > /dev/null 2>&1; then
            if counts=$(git -C "$dir" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null) \
                && [[ -n "$counts" ]]; then
                read -r behind ahead <<< "$counts"
            fi
        fi

        # Counted against the remote's default branch rather than HEAD, so a
        # forgotten branch still shows while a different one is checked out.
        base=$(git -C "$dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
        [[ -n "$base" ]] || base=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)

        # The checked out branch is dropped from the count. Its own unpushed
        # commits are what the ahead column already reports, and listing it
        # here as well reads as a second, separate problem.
        branches=()
        while IFS= read -r candidate; do
            if [[ -n "$candidate" && "$candidate" != "$branch" ]]; then
                branches+=("$candidate")
            fi
        done < <(git -C "$dir" branch --no-merged "$base" \
            --format='%(refname:short)' 2>/dev/null)

        printf '%-*s  %-20s  %5s  %6s  %5s  %8s\n' \
            "$width" "$name" "$branch" "$ahead" "$behind" "$dirty" "${#branches[@]}"

        if (( ${#branches[@]} > 0 )); then
            detail+=("$name: ${branches[*]}")
        fi
    done

    if [[ "$list_branches" == "yes" && ${#detail[@]} -gt 0 ]]; then
        printf '\n[*] Unmerged branches:\n'
        printf '    %s\n' "${detail[@]}"
    fi

    if (( ${#remoteless[@]} > 0 )); then
        printf '\n[*] No origin remote: %s\n' "${remoteless[*]}"
    fi

    if (( ${#failed[@]} > 0 )); then
        printf '\n[!] Fetch failed, ahead and behind may be stale: %s\n' "${failed[*]}" >&2
        [[ "$debug" == "yes" ]] || printf '[*] Re-run with --debug to see why\n' >&2
    fi
}

# function: w_git_disable_project_for_user
w_git_disable_project_for_user() {
    echo -n "[*] Enter GitHub user/org name: "
    read -r TARGET
    JSON_FIELDS="nameWithOwner,hasProjectsEnabled"
    REPO_METADATA=$(gh repo list "$TARGET" -L 100 --no-archived --json $JSON_FIELDS)
    # Loop repos, check for enabled project and disable the project
    jq -c '.[]' <<< "$REPO_METADATA" | while read -r JSON; do
        hasProjectsEnabled=$(jq -c '.hasProjectsEnabled | tostring' <<< "$JSON"  | tr -d '"')
        nameWithOwner=$(jq -c '.nameWithOwner' <<< "$JSON"  | tr -d '"')
        echo "[*] $nameWithOwner | $hasProjectsEnabled"
        # Disable the repository wiki if it is enabled
        if [ "$hasProjectsEnabled" = "true" ]; then
            echo "[*] Disabling repository project..."
            gh repo edit "$nameWithOwner" --enable-projects=false
        fi
    done
}

# function: w_git_disable_wiki_for_user
w_git_disable_wiki_for_user() {
    echo -n "[*] Enter GitHub user/org name: "
    read -r TARGET
    JSON_FIELDS="nameWithOwner,hasWikiEnabled"
    REPO_METADATA=$(gh repo list "$TARGET" -L 100 --no-archived --json $JSON_FIELDS)

    # Loop repos, check for enabled wiki and disable the wiki
    jq -c '.[]' <<< "$REPO_METADATA" | while read -r JSON; do
        hasWikiEnabled=$(jq -c '.hasWikiEnabled | tostring' <<< "$JSON"  | tr -d '"')
        nameWithOwner=$(jq -c '.nameWithOwner' <<< "$JSON"  | tr -d '"')
        echo "[*] $nameWithOwner | $hasWikiEnabled"
        # Disable the repository wiki if it is enabled
        if [ "$hasWikiEnabled" = "true" ]; then
            echo "[*] Disabling repository wiki..."
            gh repo edit "$nameWithOwner" --enable-wiki=false
        fi
    done
}
