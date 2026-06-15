# shellcheck shell=bash
# shellcheck disable=SC2034 

_print_help() {
    cat <<'EOF'
Usage: war10ck [flags] <subcommand> [args]

Flags:
  -d, --debug   Enable debug output and command tracing (set -x)
  -l, --local   Source scripts from the local dist/ directory instead of remote URL
  -s, --skip    Skip manifest checksum verification
  -h, --help    Show this help message

Subcommands:
  version       Print the current war10ck version
  update        Update war10ck to the latest release
  install       Install a specific module (e.g., 'war10ck install polybar')
  config        Configure a specific module (e.g., 'war10ck config polybar')
  setup         Install and configure a specific module in one step (e.g., 'war10ck setup polybar')
  launch        Launch a specific module (e.g., 'war10ck launch polybar')
  list          List all available modules and their capabilities
  nuke          Remove all war10ck configuration and installed tools

EOF
}

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

if [[ "$WAR10CK_LOCAL" == "1" ]]; then
    if [[ -d "$PWD/dist/modules" ]]; then
        BASE_URL="$PWD/dist"
    elif [[ -d "$PWD/modules" ]]; then
        BASE_URL="$PWD"
    else
        echo "[!] Local mode: cannot find a modules/ directory under $PWD or $PWD/dist"
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
export BASE_URL

if [[ "$WAR10CK_LOCAL" == "1" ]]; then
    WAR10CK_MANIFEST=$(cat "$BASE_URL/checksums.txt")
    export WAR10CK_MANIFEST
elif [[ "${_filtered_args[0]:-}" == "update" ]]; then
    export WAR10CK_MANIFEST=""
else
    _manifest_tmp=$(mktemp --suffix=.txt)
    $FETCH_CMD "$_manifest_tmp" "$BASE_URL/checksums.txt"
    if [[ "${WAR10CK_SKIP_CHECKSUMS:-0}" != "1" ]]; then
        _manifest_filtered=$(mktemp --suffix=.txt)
        grep -v ' war10ck$' "$_manifest_tmp" > "$_manifest_filtered"
        _verify_checksum "$_manifest_filtered" "$CHECKSUMS_SHA256"
        rm -f "$_manifest_filtered"
    fi
    WAR10CK_MANIFEST=$(cat "$_manifest_tmp")
    export WAR10CK_MANIFEST
    rm -f "$_manifest_tmp"
fi

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
