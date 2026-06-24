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

# function: w_git_bump_submodules
w_git_bump_submodules() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "[!] Not inside a git repository"
        return 1
    fi

    local sub_paths=()
    while IFS= read -r path; do
        sub_paths+=("$path")
    done < <(git submodule status | awk '{print $2}')

    if [[ ${#sub_paths[@]} -eq 0 ]]; then
        echo "[!] No submodules found"
        return 1
    fi

    for sub_path in "${sub_paths[@]}"; do
        w_git_bump_submodule "$sub_path"
    done
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

# function: w_git_verbs_commit
w_git_verbs_commit() {
    echo "------------------------------------------------------------------------"
    printf "%-10s %s\n" "feat:" "Add a brand new feature or functionality."
    printf "%-10s %s\n" "fix:" "Fix a bug or resolve an issue."
    printf "%-10s %s\n" "chore:" "Routine maintenance, dependency updates, or minor tasks."
    printf "%-10s %s\n" "docs:" "Changes to documentation like READMEs or comments."
    printf "%-10s %s\n" "style:" "Formatting changes that don't affect logic (e.g., linting)."
    printf "%-10s %s\n" "refactor:" "Restructure code without changing external behavior."
    printf "%-10s %s\n" "test:" "Add missing tests or correct existing ones."
    printf "%-10s %s\n" "perf:" "A code change that specifically improves performance."
    printf "%-10s %s\n" "build:" "Changes affecting the build system or dependencies."
    printf "%-10s %s\n" "ci:" "Changes to CI/CD configuration files and scripts."
    echo "------------------------------------------------------------------------"
}
