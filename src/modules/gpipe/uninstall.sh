#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

GPIPE_DIR="$HOME/.war10ck/gpipe.d"

# Read a key from a registry file.
#
# Arguments:
#   $1 - Registry file path
#   $2 - Key name
#   $3 - Default used when the key is absent or empty (optional)
_registry_get() {
  local value
  value=$(grep -E "^$2=" "$1" 2>/dev/null | tail -1 | cut -d'=' -f2-)
  printf '%s\n' "${value:-${3:-}}"
}

# The registry is the only record of what was installed, so the binaries have
# to go before the directory that names them. Both install locations are tried
# regardless of the mode= key: it records where a tool goes now, not where an
# earlier run may have put it, and a stale copy left on PATH would shadow
# nothing but confuse everything.
if [[ -d "${GPIPE_DIR}" ]]; then
  for _file in "${GPIPE_DIR}"/*; do
    [[ -f "${_file}" ]] || continue
    _binary=$(_registry_get "${_file}" binary "$(basename "${_file}")")
    w_sudo_remove_file "/usr/local/bin/${_binary}"
    w_remove_file "$HOME/.local/bin/${_binary}"
  done
fi

w_remove_dir "$GPIPE_DIR"

w_log_info "gpipe registry and its tools uninstalled."
