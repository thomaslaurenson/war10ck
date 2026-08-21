#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

GPIPE_DIR="$HOME/.war10ck/gpipe.d"

# The registry is deployed before it is read, so a tool added upstream is
# picked up by the same run that installs it. Files dropped in by hand are
# left alone by the deploy and still take part in the loop below.
for tool in gpipe moon narc prongs smount; do
  w_deploy_remote_file "modules/gpipe/files/${tool}" "$GPIPE_DIR/${tool}"
done

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

# Print the installed version of a binary, "-" when it is not on PATH, or "?"
# when it printed nothing usable. Tools disagree on version output: moon prints
# "0.3.0" while cobra's default prints "gpipe 1.4.0", so the last field is
# taken and any leading v stripped, matching w_github_latest_tag.
_installed_version() {
  local path version
  path=$(type -P "$1" 2>/dev/null) || true
  if [[ -z "${path}" ]]; then
    printf -- '-\n'
    return 0
  fi
  version=$("${path}" version 2>/dev/null | head -1 | awk '{print $NF}') || true
  version=${version#v}
  printf '%s\n' "${version:-?}"
}

# Resolve the work before touching sudo or the network, so a run with nothing
# to do neither prompts for a password nor downloads anything.
_pending=()
for _file in "${GPIPE_DIR}"/*; do
  [[ -f "${_file}" ]] || continue
  _name=$(basename "${_file}")

  _repo=$(_registry_get "${_file}" repo)
  if [[ -z "${_repo}" ]]; then
    w_log_error "${_name}: no repo= key, skipping"
    continue
  fi
  _binary=$(_registry_get "${_file}" binary "${_name}")
  _mode=$(_registry_get "${_file}" mode system)

  _installed=$(_installed_version "${_binary}")
  _latest=$(w_github_latest_tag "${_repo}" 2>/dev/null) || true
  _latest=${_latest:-?}

  # A tool is installed unless it can be proven current. Missing wins over
  # everything: an unreachable GitHub API must not stop a first install. But a
  # tool that is present and cannot be checked is left alone rather than
  # reinstalled, so a rate-limited run is a no-op instead of five downloads.
  if [[ "${_installed}" == "-" ]]; then
    w_log_info "${_name}: not installed"
  elif [[ "${_latest}" == "?" ]]; then
    w_log_info "${_name}: could not reach GitHub, leaving the installed copy in place"
    continue
  elif [[ "${_installed}" == "${_latest}" ]]; then
    w_log_info "${_name}: up to date (${_installed})"
    continue
  else
    w_log_info "${_name}: ${_installed} -> ${_latest}"
  fi

  _pending+=("${_name}|${_repo}|${_mode}")
done

if (( ${#_pending[@]} == 0 )); then
  w_log_info "gpipe registry installed to $GPIPE_DIR"
  w_log_info "All registered tools are up to date."
  exit 0
fi

# Prime the sudo timestamp once, rather than paying a password prompt per tool
# as each installer runs.
for _entry in "${_pending[@]}"; do
  if [[ "${_entry##*|}" == "system" ]]; then
    w_log_info "Priming sudo for system installs..."
    sudo -v || { w_log_error "sudo is required for system installs"; exit 1; }
    break
  fi
done

# Each tool ships its own installer, which already handles platform detection,
# cosign verification, checksums and PATH. The latest release always serves the
# latest installer, so running it is both the install and the update path.
#
# The installer is downloaded to a file rather than piped into bash. Piping
# would let it consume this loop's stdin, and running from a file is what lets
# sudo drive it without a second prompt.
_rc=0
for _entry in "${_pending[@]}"; do
  IFS='|' read -r _name _repo _mode <<< "${_entry}"
  w_log_info "Installing ${_name} from ${_repo}..."

  _release_url="https://github.com/${_repo}/releases/latest/download"
  _tmpinstaller=$(mktemp --suffix="-${_name}-install.sh")
  if ! w_download "${_release_url}/install.sh" "${_tmpinstaller}"; then
    w_log_error "${_name}: failed to download installer"
    rm -f "${_tmpinstaller}"
    _rc=1
    continue
  fi

  # The installer is about to run as root, so it is checked against the
  # release's own checksums.txt before execution rather than trusted for
  # having arrived over TLS.
  if ! w_github_checksums_verify "${_tmpinstaller}" "install.sh" \
      "${_release_url}/checksums.txt"; then
    w_log_error "${_name}: installer failed verification, skipping"
    rm -f "${_tmpinstaller}"
    _rc=1
    continue
  fi

  if [[ "${_mode}" == "user" ]]; then
    bash "${_tmpinstaller}" --user || { w_log_error "${_name}: installer failed"; _rc=1; }
  else
    # Run the whole installer as root so its unprivileged write to
    # /usr/local/bin never fails, and its interactive sudo menu never opens.
    sudo bash "${_tmpinstaller}" --system || { w_log_error "${_name}: installer failed"; _rc=1; }
  fi
  rm -f "${_tmpinstaller}"
done

w_log_info "gpipe registry installed to $GPIPE_DIR"
w_log_info "Add a tool by dropping a file with repo=owner/name into that directory."
exit "${_rc}"
