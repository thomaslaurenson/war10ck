#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Temp paths are registered here and removed by the EXIT trap, so a failed
# download or a checksum mismatch cannot leave a half-fetched archive behind.
_tmppaths=()
_cleanup() {
  [[ ${#_tmppaths[@]} -gt 0 ]] && rm -rf "${_tmppaths[@]}"
  return 0
}
trap _cleanup EXIT

w_apt_install unzip

# Update FNM_VERSION and FNM_SHA256 together when bumping.
# To get the hash: curl -fsSL "https://github.com/Schniz/fnm/releases/download/vVERSION/fnm-linux.zip" | sha256sum
readonly FNM_VERSION="1.39.0"
readonly FNM_SHA256="7807664f39d39fc518da1c35ba0181e4b3267603c4b1dedeb4b5fc6ae440a224"
readonly FNM_ARCHIVE="fnm-linux.zip"

# Pinned rather than left to fnm's own default, so install, config and
# uninstall all name the same tree even if that default ever moves.
readonly FNM_DIR="${HOME}/.local/share/fnm"
export FNM_DIR

# Node lines kept installed. 24 is Active LTS and the default; 26 is Current
# and becomes LTS in October 2026; 22 is Maintenance LTS until April 2027 and
# is here for projects still pinned to it.
readonly NODE_VERSIONS=(22 24 26)
readonly NODE_DEFAULT="24"

_tmpfile=$(mktemp --suffix=-"${FNM_ARCHIVE}")
_tmppaths+=("${_tmpfile}")
w_download \
  "https://github.com/Schniz/fnm/releases/download/v${FNM_VERSION}/${FNM_ARCHIVE}" \
  "${_tmpfile}"

if ! w_verify_sha256 "${_tmpfile}" "${FNM_SHA256}"; then
  exit 1
fi

_tmpdir=$(mktemp -d --suffix=-fnm)
_tmppaths+=("${_tmpdir}")
w_q unzip -q "${_tmpfile}" fnm -d "${_tmpdir}"
sudo install -m 0755 "${_tmpdir}/fnm" /usr/local/bin/fnm

for _version in "${NODE_VERSIONS[@]}"; do
  w_log_info "Installing Node ${_version}"
  w_q fnm install "${_version}"
done

# The default alias is what the env fragment puts on PATH, so this decides
# which Node a shell gets when the directory names no version of its own.
w_q fnm alias "${NODE_DEFAULT}" default

# Global npm packages are installed under the Node version that was active at
# the time, so one install is invisible from every other version. Installing
# per version is what makes the tool present whichever one is in use.
for _version in "${NODE_VERSIONS[@]}"; do
  w_q fnm exec --using="${_version}" npm install -g npm-check@latest
done

w_log_info "fnm module installed."
