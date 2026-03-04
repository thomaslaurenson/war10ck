# shellcheck shell=bash
# shellcheck disable=SC2034  # BASE_URL and FETCH_CMD are used across bundled files

# Toggle to use local files for testing
IS_LOCAL=false
if [ "$IS_LOCAL" = true ]; then
    _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # Only switch to local-file mode if the support directories exist next to
    # this script (i.e. we are running directly from dist/, not from an
    # installed path like /usr/local/bin/ that has no config/ or install/).
    if [[ -d "$_SCRIPT_DIR/config" && -d "$_SCRIPT_DIR/install" ]]; then
        cd "$_SCRIPT_DIR" || exit 1
        BASE_URL="."
    fi
fi

# Determine fetch command to use
if [ "$IS_LOCAL" = true ] && [[ "${BASE_URL}" == "." ]]; then
    FETCH_CMD="_bcp"
elif command -v curl &> /dev/null; then
    FETCH_CMD="curl -fsSL -o"
elif command -v wget &> /dev/null; then
    FETCH_CMD="wget -q -O"
else
    echo "[!] No fetch command found. Exiting."
    exit 1
fi

# Fetch and verify the remote manifest before any network operations
_load_manifest

# Validate and dispatch subcommand
subcommand=$1
if ! _is_valid_subcommand "$subcommand"; then
    echo "[!] Invalid subcommand: $subcommand"
    echo "[!] Valid subcommands: ${VALID_SUBCOMMANDS[*]}"
    echo "[!] Exiting."
    exit 1
fi

if declare -f "$subcommand" > /dev/null 2>&1; then
    "$@"
else
    echo "[!] Invalid subcommand: $subcommand"
    echo "[!] No matching function."
    echo "[!] Exiting."
    exit 1
fi