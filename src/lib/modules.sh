# shellcheck shell=bash

# Fetch and execute a single script from a module or profile.
# Gracefully skips if the script does not exist in the manifest.
#
# Arguments:
#   $1 - Path prefix (e.g. "modules/polybar" or "profiles/desktop")
#   $2 - Action name (e.g. "install" or "config")
_run_script() {
  local prefix=$1
  local action=$2
  local manifest_key="${prefix}/${action}.sh"

  if ! grep -q "${manifest_key}$" <<< "${WAR10CK_MANIFEST}"; then
    return 0
  fi

  printf '[*] Running %s for %s...\n' "${action}" "${prefix}"
  local _tmpfile
  _tmpfile=$(mktemp --suffix="-${action}.sh")

  ${FETCH_CMD} "${_tmpfile}" "${BASE_URL}/${manifest_key}"
  _verify_from_manifest "${_tmpfile}" "${manifest_key}"
  bash "${_tmpfile}"
  rm -f "${_tmpfile}"
}

# List all modules, filtered optionally by action support.
# Output is formatted for display with capability tags.
#
# Arguments:
#   $1 - Optional action to filter by (e.g. "install" or "config")
# Outputs:
#   stdout: formatted module list
_list_modules() {
  local action=${1:-}
  local modules
  modules=$(grep -oE "modules/[^/]+" <<< "${WAR10CK_MANIFEST}" | cut -d'/' -f2 | sort -u)

  for mod in ${modules}; do
    local caps=""
    grep -q "modules/${mod}/install.sh"   <<< "${WAR10CK_MANIFEST}" && caps+="[install] "
    grep -q "modules/${mod}/config.sh"    <<< "${WAR10CK_MANIFEST}" && caps+="[config] "
    grep -q "modules/${mod}/uninstall.sh" <<< "${WAR10CK_MANIFEST}" && caps+="[uninstall] "

    if [[ -n "${action}" ]]; then
      grep -q "modules/${mod}/${action}.sh" <<< "${WAR10CK_MANIFEST}" || continue
    fi

    printf '  %-18s %s\n' "${mod}" "${caps}"
  done
}

# List all profiles with their member modules, sourced from each profile's meta file.
#
# Outputs:
#   stdout: formatted profile list with member modules
_list_profiles() {
  local profiles
  profiles=$(grep -oE "profiles/[^/]+" <<< "${WAR10CK_MANIFEST}" | cut -d'/' -f2 | sort -u)

  for profile in ${profiles}; do
    local meta_key="profiles/${profile}/meta"
    if ! grep -q "${meta_key}$" <<< "${WAR10CK_MANIFEST}"; then
      continue
    fi

    local _tmpfile
    _tmpfile=$(mktemp --suffix="-${profile}-meta")
    ${FETCH_CMD} "${_tmpfile}" "${BASE_URL}/${meta_key}"

    local members
    local description
    members=$(grep "^MODULES=" "${_tmpfile}" | cut -d'=' -f2- | tr -d '"')
    description=$(grep "^DESCRIPTION=" "${_tmpfile}" | cut -d'=' -f2- | tr -d '"')
    rm -f "${_tmpfile}"

    local members_display
    members_display=$(printf '%s' "${members}" | tr ' ' ',')
    printf '  %-18s %s\n' "${profile}" "${members_display}"
    [[ -n "${description}" ]] && printf '  %-18s %s\n' "" "${description}"
  done
}

# Run install and config for every module listed in a profile's meta file.
#
# Arguments:
#   $1 - Profile name
# Environment:
#   WAR10CK_MANIFEST - loaded manifest content
# Returns:
#   exits 1 if the profile has no meta file
_run_profile() {
  local profile=$1
  local meta_key="profiles/${profile}/meta"

  if ! grep -q "${meta_key}$" <<< "${WAR10CK_MANIFEST}"; then
    printf '[!] Profile %s has no meta file. Cannot run.\n' "${profile}" >&2
    exit 1
  fi

  local _tmpfile
  _tmpfile=$(mktemp --suffix="-${profile}-meta")
  ${FETCH_CMD} "${_tmpfile}" "${BASE_URL}/${meta_key}"
  local members
  members=$(grep "^MODULES=" "${_tmpfile}" | cut -d'=' -f2- | tr -d '"')
  rm -f "${_tmpfile}"

  printf '[*] Applying profile: %s\n' "${profile}"
  for mod in ${members}; do
    _run_script "modules/${mod}" "install"
    _run_script "modules/${mod}" "config"
  done
  printf '[*] Profile %s complete.\n' "${profile}"
}

# Uninstall a module. Shows available modules when called with no argument.
#
# Arguments:
#   $1 - Module name (optional)
uninstall() {
  local target=${1:-}
  if [[ -z "${target}" ]]; then
    printf '\nModules with uninstall support:\n\n'
    _list_modules "uninstall"
    printf '\nUsage: war10ck uninstall <module>\n\n'
    exit 0
  fi
  if ! grep -q "modules/${target}/" <<< "${WAR10CK_MANIFEST}"; then
    printf '[!] Unknown module: %s\n' "${target}" >&2
    exit 1
  fi
  _run_script "modules/${target}" "uninstall"
}

# Install a module. Shows available modules when called with no argument.
#
# Arguments:
#   $1 - Module name (optional)
install() {
  local target=${1:-}
  if [[ -z "${target}" ]]; then
    printf '\nModules with install support:\n\n'
    _list_modules "install"
    printf '\nUsage: war10ck install <module>\n\n'
    exit 0
  fi
  if ! grep -q "modules/${target}/" <<< "${WAR10CK_MANIFEST}"; then
    printf '[!] Unknown module: %s\n' "${target}" >&2
    exit 1
  fi
  _run_script "modules/${target}" "install"
}

# Configure a module. Shows available modules when called with no argument.
#
# Arguments:
#   $1 - Module name (optional)
config() {
  local target=${1:-}
  if [[ -z "${target}" ]]; then
    printf '\nModules with config support:\n\n'
    _list_modules "config"
    printf '\nUsage: war10ck config <module>\n\n'
    exit 0
  fi
  if ! grep -q "modules/${target}/" <<< "${WAR10CK_MANIFEST}"; then
    printf '[!] Unknown module: %s\n' "${target}" >&2
    exit 1
  fi
  _run_script "modules/${target}" "config"
}

# Apply a module or profile (install + config). Shows all targets when called with no argument.
# Profiles take precedence over modules when names conflict.
#
# Arguments:
#   $1 - Module or profile name (optional)
apply() {
  local target=${1:-}
  if [[ -z "${target}" ]]; then
    printf '\nModules:\n\n'
    _list_modules
    printf '\nProfiles:\n\n'
    _list_profiles
    printf '\nUsage: war10ck apply <module|profile>\n\n'
    exit 0
  fi

  if grep -q "profiles/${target}/" <<< "${WAR10CK_MANIFEST}"; then
    _run_profile "${target}"
  elif grep -q "modules/${target}/" <<< "${WAR10CK_MANIFEST}"; then
    printf '[*] Applying module: %s\n' "${target}"
    _run_script "modules/${target}" "install"
    _run_script "modules/${target}" "config"
    printf '[*] %s complete.\n' "${target}"
  else
    printf '[!] Unknown module or profile: %s\n' "${target}" >&2
    exit 1
  fi
}
