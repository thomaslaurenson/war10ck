# shellcheck shell=bash
# shellcheck disable=SC2034

_print_help() {
  cat <<'HELP'

Usage: war10ck [flags] <subcommand> [target]

Flags:
  -d, --debug   Enable debug output and command tracing (set -x)
  -l, --local   Source scripts from the local dist/ directory instead of remote URL
  -s, --skip    Skip manifest checksum verification
  -h, --help    Show this help message

Subcommands:
  install       Install a module        (run without target to list available)
  config        Configure a module      (run without target to list available)
  apply         Apply a module or profile - install + config in one step
                                        (run without target to list all)
  uninstall     Uninstall a module      (run without target to list available)
  update        Update war10ck to the latest release
  version       Print the current war10ck version

HELP
}

_print_no_args() {
  cat <<'NOARGS'

war10ck - personal system configuration tool

Usage: war10ck [flags] <subcommand> [target]

Subcommands:
  install       Install a module
  config        Configure a module
  apply         Apply a module or profile (install + config)
  uninstall     Uninstall a module
  update        Update war10ck
  version       Print current version

Run 'war10ck -h' for flags and details.
Run 'war10ck apply' to see all modules and profiles.

NOARGS
}

WAR10CK_DEBUG=0
WAR10CK_LOCAL=0
WAR10CK_SKIP_CHECKSUMS=0

# Dev builds automatically enable local mode and skip checksums.
# WAR10CK_BUILD is replaced with "release" by bundle.sh for release builds.
if [[ "${WAR10CK_BUILD:-dev}" == "dev" ]]; then
  WAR10CK_LOCAL=1
  WAR10CK_SKIP_CHECKSUMS=1
fi

_filtered_args=()
for _arg in "$@"; do
  case "${_arg}" in
    -d|--debug)  WAR10CK_DEBUG=1 ;;
    -l|--local)  WAR10CK_LOCAL=1 ;;
    -s|--skip)   WAR10CK_SKIP_CHECKSUMS=1 ;;
    -h|--help)   _print_help; exit 0 ;;
    *)           _filtered_args+=("${_arg}") ;;
  esac
done
export WAR10CK_DEBUG WAR10CK_LOCAL WAR10CK_SKIP_CHECKSUMS
if (( ${#_filtered_args[@]} )); then
  set -- "${_filtered_args[@]}"
else
  set --
fi

if [[ "${WAR10CK_LOCAL}" == "1" ]]; then
  if [[ -d "${PWD}/dist/modules" ]]; then
    BASE_URL="${PWD}/dist"
  elif [[ -d "${PWD}/modules" ]]; then
    BASE_URL="${PWD}"
  else
    printf '[!] Local mode: cannot find a modules/ directory under %s or %s/dist\n' "${PWD}" "${PWD}" >&2
    printf '[!] Run from the repository root or from inside the dist/ directory.\n' >&2
    exit 1
  fi
  FETCH_CMD="_bcp"
elif command -v curl &> /dev/null; then
  FETCH_CMD="curl -fsSL -o"
elif command -v wget &> /dev/null; then
  FETCH_CMD="wget -q -O"
else
  printf '[!] No fetch command found. Exiting.\n' >&2
  exit 1
fi
export BASE_URL FETCH_CMD

if [[ "${WAR10CK_LOCAL}" == "1" ]]; then
  WAR10CK_MANIFEST=$(cat "${BASE_URL}/checksums.txt")
  export WAR10CK_MANIFEST
elif [[ "${_filtered_args[0]:-}" == "update" ]]; then
  export WAR10CK_MANIFEST=""
else
  _manifest_tmp=$(mktemp --suffix=.txt)
  ${FETCH_CMD} "${_manifest_tmp}" "${BASE_URL}/checksums.txt"
  if [[ "${WAR10CK_SKIP_CHECKSUMS:-0}" != "1" ]]; then
    _manifest_filtered=$(mktemp --suffix=.txt)
    grep -v ' war10ck$' "${_manifest_tmp}" > "${_manifest_filtered}"
    _verify_checksum "${_manifest_filtered}" "${CHECKSUMS_SHA256}"
    rm -f "${_manifest_filtered}"
  fi
  WAR10CK_MANIFEST=$(cat "${_manifest_tmp}")
  export WAR10CK_MANIFEST
  rm -f "${_manifest_tmp}"
fi

subcommand=${1:-}
if [[ -z "${subcommand}" ]]; then
  _print_no_args
  exit 0
fi

if ! _is_valid_subcommand "${subcommand}"; then
  printf '[!] Unknown subcommand: %s\n' "${subcommand}" >&2
  printf '[!] Valid subcommands: %s\n' "${VALID_SUBCOMMANDS[*]}" >&2
  printf '[!] Run '"'"'war10ck -h'"'"' for help.\n' >&2
  exit 1
fi

if declare -f "${subcommand}" > /dev/null 2>&1; then
  "$@"
else
  printf '[!] No function found for subcommand: %s\n' "${subcommand}" >&2
  exit 1
fi
