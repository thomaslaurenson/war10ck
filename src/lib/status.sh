# shellcheck shell=bash

# Registry of modules war10ck has applied on this machine. One file per module
# under registry.d, named for the module, holding key=value lines:
#
#   installed=<ISO 8601 UTC>      when install.sh last completed
#   installed_by=<war10ck version>
#   configured=<ISO 8601 UTC>     when config.sh last completed
#   configured_by=<war10ck version>
#
# The same shape as gpipe.d, so there is one registry format in this project
# rather than two.
#
# One file per module rather than a combined file: uninstall is then a single
# rm instead of a read-modify-write, two module scripts can never race on the
# same file, and ls answers "what is applied" with no parser at all.
#
# Entries are written by _run_script, never by module scripts themselves. That
# keeps the record to what actually ran: _run_script only records after the
# script exits 0, and a module has no way to claim it was applied when it was
# not. It also means a new module needs no registry code.
readonly W_REGISTRY_DIR="${HOME}/.war10ck/registry.d"

# Read a key from a registry entry.
#
# Arguments:
#   $1 - Registry file path
#   $2 - Key name
# Outputs:
#   stdout: the value, or nothing
_w_registry_get() {
  local file=$1
  local key=$2
  [[ -f "${file}" ]] || return 0
  grep -E "^${key}=" "${file}" 2>/dev/null | tail -1 | cut -d'=' -f2-
}

# Record that a module lifecycle script completed, or drop the entry when the
# module was uninstalled. Install and config are tracked separately: a module
# that is installed but never configured is a real and visible state, not a
# rounding error.
#
# Arguments:
#   $1 - Module name
#   $2 - Action: install, config or uninstall
_w_registry_record() {
  local module=$1
  local action=$2
  local file="${W_REGISTRY_DIR}/${module}"

  if [[ "${action}" == "uninstall" ]]; then
    [[ -f "${file}" ]] && rm -f "${file}"
    return 0
  fi

  local installed installed_by configured configured_by stamp
  installed=$(_w_registry_get "${file}" installed)
  installed_by=$(_w_registry_get "${file}" installed_by)
  configured=$(_w_registry_get "${file}" configured)
  configured_by=$(_w_registry_get "${file}" configured_by)
  stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  case "${action}" in
    install) installed=${stamp};  installed_by=${VERSION} ;;
    config)  configured=${stamp}; configured_by=${VERSION} ;;
    *)       return 0 ;;
  esac

  mkdir -p "${W_REGISTRY_DIR}"
  {
    printf 'installed=%s\n'      "${installed}"
    printf 'installed_by=%s\n'   "${installed_by}"
    printf 'configured=%s\n'     "${configured}"
    printf 'configured_by=%s\n'  "${configured_by}"
  } > "${file}"
}

# Print the modules war10ck has applied on this machine, oldest field values
# intact and newest action per module.
#
# Only what the registry holds is shown. A module missing from the table has no
# entry, which means war10ck has not applied it since the registry existed - it
# does not mean the software is absent. Reporting presence would need a
# detection rule per module and the remote manifest to enumerate them, and a
# guess is worth less here than a fact.
status() {
  local -a files=()
  if [[ -d "${W_REGISTRY_DIR}" ]]; then
    local f
    for f in "${W_REGISTRY_DIR}"/*; do
      [[ -f "${f}" ]] && files+=("${f}")
    done
  fi

  if (( ${#files[@]} == 0 )); then
    w_log_info "No modules recorded yet."
    w_log_info "The registry fills in as modules are applied: ${W_REGISTRY_DIR}"
    return 0
  fi

  printf '\n%-14s %-22s %-22s %s\n' "MODULE" "INSTALLED" "CONFIGURED" "BY"
  printf '%-14s %-22s %-22s %s\n' "------" "---------" "----------" "--"

  local file module installed configured applied_by
  for file in "${files[@]}"; do
    module=$(basename "${file}")
    installed=$(_w_registry_get "${file}" installed)
    configured=$(_w_registry_get "${file}" configured)
    # The later action is the one that describes the entry's age.
    applied_by=$(_w_registry_get "${file}" configured_by)
    [[ -n "${applied_by}" ]] || applied_by=$(_w_registry_get "${file}" installed_by)
    printf '%-14s %-22s %-22s %s\n' \
      "${module}" "${installed:--}" "${configured:--}" "${applied_by:--}"
  done
  printf '\n'
}
