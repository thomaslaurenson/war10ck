# shellcheck shell=bash
# shellcheck disable=SC2034  # BASE_URL and FETCH_CMD are used across bundled files

_print_help() {
    cat <<'EOF'
Usage: war10ck [flags] <subcommand> [args]

Flags:
  -d, --debug   Enable debug output and command tracing (set -x) in install scripts
  -l, --local   Source scripts from the local dist/ directory instead of the remote URL
  -s, --skip    Skip manifest checksum verification (useful with --local)
  -h, --help    Show this help message

Subcommands:
  version       Print the current war10ck version
  update        Update war10ck to the latest release
  config        Apply dotfile and shell configuration (aliases, gitconfig, tmux, etc.)
  install       Install a tool or package (e.g. war10ck install golang)
  nuke          Remove all war10ck configuration and installed tools

EOF
}

# Global flag parsing — must run before IS_LOCAL / FETCH_CMD setup so that
# -l/--local can influence both. All recognised flags are stripped from $@
# before subcommand dispatch. Exported vars are inherited by install scripts.
WAR10CK_DEBUG=0
WAR10CK_LOCAL=0
WAR10CK_SKIP_CHECKSUMS=0
_filtered_args=()
for _arg in "$@"; do
    case "$_arg" in
        -d|--debug)  WAR10CK_DEBUG=1 ;;
        -l|--local)  WAR10CK_LOCAL=1 ;;
        -s|--skip)   WAR10CK_SKIP_CHECKSUMS=1 ;;
        -h|--help)   _print_help; exit 0 ;;
        *)           _filtered_args+=("$_arg") ;;
    esac
done
export WAR10CK_DEBUG WAR10CK_LOCAL WAR10CK_SKIP_CHECKSUMS
if (( ${#_filtered_args[@]} )); then
    set -- "${_filtered_args[@]}"
else
    set --
fi

# Resolve fetch command and base URL.
# -l/--local: look for a dist/ directory near $PWD (repo-root usage) or fall
# back to $PWD itself (running from inside dist/).
IS_LOCAL=false
if [[ "$WAR10CK_LOCAL" == "1" ]]; then
    IS_LOCAL=true
    if [[ -d "$PWD/dist/install" ]]; then
        BASE_URL="$PWD/dist"
    elif [[ -d "$PWD/install" ]]; then
        BASE_URL="$PWD"
    else
        echo "[!] Local mode: cannot find an install/ directory under $PWD or $PWD/dist"
        echo "[!] Run from the repository root or from inside the dist/ directory."
        exit 1
    fi
    FETCH_CMD="_bcp"
elif command -v curl &> /dev/null; then
    FETCH_CMD="curl -fsSL -o"
elif command -v wget &> /dev/null; then
    FETCH_CMD="wget -q -O"
else
    echo "[!] No fetch command found. Exiting."
    exit 1
fi

# Load and verify the remote manifest before any network operations.
# Skipped for:
# local mode using "-l" and "--local"
# checksum skipping mode using "-s" and "--skip"
# update subcommand which uses TLS for manifest delivery
if [[ "$IS_LOCAL" == "true" || "${WAR10CK_SKIP_CHECKSUMS:-0}" == "1" || "${_filtered_args[0]:-}" == "update" ]]; then
    export WAR10CK_MANIFEST=""
else
    _manifest_tmp=$(mktemp --suffix=.txt)
    $FETCH_CMD "$_manifest_tmp" "$BASE_URL/checksums.txt"
    _verify_checksum "$_manifest_tmp" "$CHECKSUMS_SHA256"
    WAR10CK_MANIFEST=$(cat "$_manifest_tmp")
    export WAR10CK_MANIFEST
    rm -f "$_manifest_tmp"
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