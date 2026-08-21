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

# The manifest for this build, replaced by bundle.sh with the real thing. It
# lives here rather than in constants.sh so it stays below completion.sh in the
# bundle: rundmc sources war10ck into every interactive shell, and there is no
# reason to carry ten kilobytes of hashes into each one.
#
# Embedding rather than fetching is safe because the binary is already pinned to
# exactly one manifest: CHECKSUMS_SHA256 makes _load_manifest reject any remote
# manifest that hashes differently, so these are the same bytes it would have
# downloaded. Fetching would also answer the wrong question, reporting modules
# as changed against a release this binary would refuse to install.
#
# Empty in a dev build and when this file is sourced directly, which reads as an
# unknown state rather than a false match. Assigned from the environment rather
# than declared readonly so a test can supply one; bundle.sh replaces the whole
# line with a readonly holding the real manifest.
WAR10CK_EMBEDDED_MANIFEST="${WAR10CK_EMBEDDED_MANIFEST:-}"

# Print the hash a manifest records for a path, or nothing when absent.
#
# Arguments:
#   $1 - Manifest contents
#   $2 - Path to look up, as it appears in the manifest
# Outputs:
#   stdout: the sha256, or nothing
_w_manifest_sha() {
  printf '%s\n' "$1" | awk -v key="$2" '$2 == key { print $1; exit }'
}

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
  # awk rather than grep, and not for style: a key that is absent is normal
  # here, because an entry written by an older war10ck has no hash fields at
  # all. grep signals "no match" by exiting 1, which as the function's last
  # command makes the function itself return 1, and under errexit that takes
  # down the caller mid-record. awk exits 0 whether or not it matched.
  awk -v key="${key}" '
    index($0, key "=") == 1 { value = substr($0, length(key) + 2) }
    END { if (value != "") print value }
  ' "${file}"
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

  local installed installed_by installed_sha
  local configured configured_by configured_sha
  local stamp sha
  installed=$(_w_registry_get "${file}" installed)
  installed_by=$(_w_registry_get "${file}" installed_by)
  installed_sha=$(_w_registry_get "${file}" installed_sha)
  configured=$(_w_registry_get "${file}" configured)
  configured_by=$(_w_registry_get "${file}" configured_by)
  configured_sha=$(_w_registry_get "${file}" configured_sha)
  stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # The manifest is already loaded and verified for any action that reaches
  # here, so the hash of the script that just ran costs nothing to record.
  sha=$(_w_manifest_sha "${WAR10CK_MANIFEST:-}" "modules/${module}/${action}.sh")

  case "${action}" in
    install) installed=${stamp};  installed_by=${VERSION}; installed_sha=${sha} ;;
    config)  configured=${stamp}; configured_by=${VERSION}; configured_sha=${sha} ;;
    *)       return 0 ;;
  esac

  mkdir -p "${W_REGISTRY_DIR}"
  {
    printf 'installed=%s\n'      "${installed}"
    printf 'installed_by=%s\n'   "${installed_by}"
    printf 'installed_sha=%s\n'  "${installed_sha}"
    printf 'configured=%s\n'     "${configured}"
    printf 'configured_by=%s\n'  "${configured_by}"
    printf 'configured_sha=%s\n' "${configured_sha}"
  } > "${file}"
}

# Print the state of a recorded module against the manifest this build ships:
# current, changed, or unknown.
#
# A module is only "current" when every action recorded for it still matches.
# Anything unresolvable is "unknown" rather than assumed good: an entry written
# before hashes were recorded, or a dev build with no embedded manifest, must
# not read as a clean bill of health.
#
# Arguments:
#   $1 - Registry file path
#   $2 - Module name
_w_registry_state() {
  local file=$1
  local module=$2
  [[ -n "${WAR10CK_EMBEDDED_MANIFEST}" ]] || { printf 'unknown\n'; return 0; }

  local action ran recorded current compared=0
  for action in install config; do
    case "${action}" in
      install) ran=$(_w_registry_get "${file}" installed)
               recorded=$(_w_registry_get "${file}" installed_sha) ;;
      config)  ran=$(_w_registry_get "${file}" configured)
               recorded=$(_w_registry_get "${file}" configured_sha) ;;
    esac

    # An action with no timestamp never ran, so there is nothing to compare.
    [[ -n "${ran}" ]] || continue
    [[ -n "${recorded}" ]] || { printf 'unknown\n'; return 0; }

    current=$(_w_manifest_sha "${WAR10CK_EMBEDDED_MANIFEST}" "modules/${module}/${action}.sh")
    [[ -n "${current}" ]] || { printf 'unknown\n'; return 0; }
    [[ "${recorded}" == "${current}" ]] || { printf 'changed\n'; return 0; }
    compared=1
  done

  if (( compared )); then
    printf 'current\n'
  else
    printf 'unknown\n'
  fi
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

  printf '\n%-14s %-22s %-22s %-9s %s\n' \
    "MODULE" "INSTALLED" "CONFIGURED" "BY" "STATE"
  printf '%-14s %-22s %-22s %-9s %s\n' \
    "------" "---------" "----------" "--" "-----"

  local file module installed configured applied_by state
  local changed=0
  for file in "${files[@]}"; do
    module=$(basename "${file}")
    installed=$(_w_registry_get "${file}" installed)
    configured=$(_w_registry_get "${file}" configured)
    # The later action is the one that describes the entry's age.
    applied_by=$(_w_registry_get "${file}" configured_by)
    [[ -n "${applied_by}" ]] || applied_by=$(_w_registry_get "${file}" installed_by)
    state=$(_w_registry_state "${file}" "${module}")
    [[ "${state}" == "changed" ]] && changed=1
    printf '%-14s %-22s %-22s %-9s %s\n' \
      "${module}" "${installed:--}" "${configured:--}" "${applied_by:--}" "${state}"
  done
  printf '\n'

  if (( changed )); then
    w_log_info "Modules marked changed differ from this build. Re-apply them to catch up."
  fi
}
