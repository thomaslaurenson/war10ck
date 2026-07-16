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

# Parse global flags, leaving the non-flag arguments in the _ARGS global so the
# caller can reset the positional parameters from them.
#
# Arguments:
#   $@ - Raw command-line arguments
# Environment:
#   Sets WAR10CK_DEBUG, WAR10CK_LOCAL, WAR10CK_SKIP_CHECKSUMS and _ARGS
_parse_flags() {
  _ARGS=()
  local arg
  for arg in "$@"; do
    case "${arg}" in
      -d|--debug)  WAR10CK_DEBUG=1 ;;
      -l|--local)  WAR10CK_LOCAL=1 ;;
      -s|--skip)   WAR10CK_SKIP_CHECKSUMS=1 ;;
      -h|--help)   _print_help; exit 0 ;;
      *)           _ARGS+=("${arg}") ;;
    esac
  done
  export WAR10CK_DEBUG WAR10CK_LOCAL WAR10CK_SKIP_CHECKSUMS
}

# Select the source of module scripts and the command used to fetch them.
# Local mode copies from disk; otherwise curl or wget pulls over HTTPS.
#
# Environment:
#   Sets and exports BASE_URL and FETCH_CMD
_resolve_fetch() {
  if [[ "${WAR10CK_LOCAL}" == "1" ]]; then
    if [[ -d "${PWD}/dist/modules" ]]; then
      BASE_URL="${PWD}/dist"
    elif [[ -d "${PWD}/modules" ]]; then
      BASE_URL="${PWD}"
    else
      printf '[!] Local mode: cannot find a modules/ directory under %s or %s/dist\n' \
        "${PWD}" "${PWD}" >&2
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
}

# Load the checksum manifest that every module fetch is verified against.
# The war10ck entry is filtered out before verification because the binary
# hash is appended to the manifest after CHECKSUMS_SHA256 is embedded.
#
# Only the subcommands that dispatch module or profile scripts need a
# manifest. version and update must keep working with no network: update
# fetches and verifies its own manifest during the upgrade.
#
# Arguments:
#   $1 - Subcommand being run
# Environment:
#   Sets and exports WAR10CK_MANIFEST
_load_manifest() {
  local subcommand=${1:-}

  case "${subcommand}" in
    install|config|apply|uninstall) ;;
    *)
      export WAR10CK_MANIFEST=""
      return 0
      ;;
  esac

  if [[ "${WAR10CK_LOCAL}" == "1" ]]; then
    WAR10CK_MANIFEST=$(cat "${BASE_URL}/checksums.txt")
    export WAR10CK_MANIFEST
    return 0
  fi

  local manifest_tmp
  manifest_tmp=$(mktemp --suffix=.txt)
  ${FETCH_CMD} "${manifest_tmp}" "${BASE_URL}/checksums.txt"
  if [[ "${WAR10CK_SKIP_CHECKSUMS:-0}" != "1" ]]; then
    local manifest_filtered
    manifest_filtered=$(mktemp --suffix=.txt)
    grep -v ' war10ck$' "${manifest_tmp}" > "${manifest_filtered}"
    _verify_checksum "${manifest_filtered}" "${CHECKSUMS_SHA256}"
    rm -f "${manifest_filtered}"
  fi
  WAR10CK_MANIFEST=$(cat "${manifest_tmp}")
  export WAR10CK_MANIFEST
  rm -f "${manifest_tmp}"
}

# Entry point: parse flags, prepare the fetch source and manifest, then
# dispatch to the function matching the requested subcommand.
main() {
  _parse_flags "$@"
  if (( ${#_ARGS[@]} )); then
    set -- "${_ARGS[@]}"
  else
    set --
  fi

  local subcommand=${1:-}
  if [[ -z "${subcommand}" ]]; then
    _print_no_args
    exit 0
  fi

  if ! _is_valid_subcommand "${subcommand}"; then
    printf '[!] Unknown subcommand: %s\n' "${subcommand}" >&2
    printf '[!] Valid subcommands: %s\n' "${VALID_SUBCOMMANDS[*]}" >&2
    printf "[!] Run 'war10ck -h' for help.\n" >&2
    exit 1
  fi

  # version is purely local; resolving a fetch source for it would fail on a
  # host with neither curl nor wget, for no benefit. update needs a fetch
  # command but never a manifest.
  case "${subcommand}" in
    version) ;;
    *)
      _resolve_fetch
      _load_manifest "${subcommand}"
      ;;
  esac

  if ! declare -f "${subcommand}" > /dev/null 2>&1; then
    printf '[!] No function found for subcommand: %s\n' "${subcommand}" >&2
    exit 1
  fi
  "$@"
}

main "$@"
