# shellcheck shell=bash
# shellcheck disable=SC2034  # BASE_URL and FETCH_CMD are used across bundled files

# Toggle to use local files for testing
IS_LOCAL=false
if [ "$IS_LOCAL" = true ]; then
    cd "$(dirname "$0")" || exit 1
    BASE_URL="."
fi

# Determine fetch command to use
if [ "$IS_LOCAL" = true ]; then
    FETCH_CMD="_bcp"
elif command -v curl &> /dev/null; then
    FETCH_CMD="curl -s -o"
elif command -v wget &> /dev/null; then
    FETCH_CMD="wget -q -O"
else
    echo "[!] No fetch command found. Exiting."
    exit 1
fi

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
