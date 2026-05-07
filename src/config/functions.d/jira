# function: w_jira_sprint
w_jira_sprint() {
    local current=true
    local open=true
    local assigned=false
    local plain=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all-sprints)
                current=false
                ;;
            --all-statuses)
                open=false
                ;;
            --assigned)
                assigned=true
                ;;
            --plain)
                plain=true
                ;;
            --help|-h)
                echo "Usage: w_jira_sprint [OPTIONS]"
                echo ""
                echo "List issues in the current sprint. Defaults to open issues only."
                echo ""
                echo "Options:"
                echo "  --all-sprints    Show sprint explorer instead of current sprint only"
                echo "  --all-statuses   Include all statuses (default: excludes Done)"
                echo "  --assigned       Filter to issues assigned to you"
                echo "  --plain          Plain text output (useful for scripting)"
                return 0
                ;;
            *)
                echo "[!] Unknown option: $1"
                echo "[*] Run 'w_jira_sprint --help' for usage"
                return 1
                ;;
        esac
        shift
    done

    local -a args=()

    $current && args+=("--current")
    $open && args+=("-q" "status != Done")
    $assigned && args+=("-a$(jira me)")
    $plain && args+=("--plain")

    jira sprint list "${args[@]}"
}

# function: w_jira_epics
w_jira_epics() {
    local open=true
    local assigned=false
    local plain=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all-statuses)
                open=false
                ;;
            --assigned)
                assigned=true
                ;;
            --plain)
                plain=true
                ;;
            --help|-h)
                echo "Usage: w_jira_epics [OPTIONS]"
                echo ""
                echo "List epics in the current project. Defaults to open epics in table view."
                echo ""
                echo "Options:"
                echo "  --all-statuses   Include all statuses (default: open only)"
                echo "  --assigned       Filter to epics reported by you"
                echo "  --plain          Plain text output (useful for scripting)"
                return 0
                ;;
            *)
                echo "[!] Unknown option: $1"
                echo "[*] Run 'w_jira_epics --help' for usage"
                return 1
                ;;
        esac
        shift
    done

    local -a args=()

    $plain && args+=("--plain") || args+=("--table")
    $open && args+=("-sOpen")
    $assigned && args+=("-r$(jira me)")

    jira epic list "${args[@]}"
}
