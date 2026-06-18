tmux () {
    local tmux_dir="$HOME/.war10ck/tmux"
    local session_name="${1:-}"

    if [[ -z "$session_name" ]]; then
        [[ -d "$tmux_dir" ]] || { echo "[!] Tmux dir not found: $tmux_dir"; return 1; }

        local sessions=()
        while IFS= read -r -d '' file; do
            sessions+=("$(basename "$file")")
        done < <(find "$tmux_dir" -maxdepth 1 -type f -print0 2>/dev/null)

        [[ ${#sessions[@]} -gt 0 ]] || { echo "[!] No session files found in $tmux_dir"; return 1; }

        PS3="[*] Select session: "
        select session_name in "${sessions[@]}"; do
            [[ -n "$session_name" ]] && break
            echo "[!] Invalid selection."
        done
    fi

    [[ -f "$tmux_dir/$session_name" ]] || { echo "[!] Session file not found: $tmux_dir/$session_name"; return 1; }

    echo "[*] Starting tmux session: $session_name"
    tmux start-server \; source-file "$tmux_dir/$session_name"
    tmux attach-session -t "$session_name"
}
