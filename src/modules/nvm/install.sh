#!/usr/bin/env bash

# shellcheck disable=SC1091

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Update NVM_SHA256 when bumping NVM_VERSION.
# To get the hash: curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/vVERSION/install.sh" | sha256sum
readonly NVM_VERSION="0.40.3"
readonly NVM_SHA256="2d8359a64a3cb07c02389ad88ceecd43f2fa469c06104f92f98df5b6f315275f"

readonly NVM_INSTALLER_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh"

_tmpinstaller=$(mktemp --suffix=-nvm-install.sh)
w_download "${NVM_INSTALLER_URL}" "${_tmpinstaller}"

if ! w_verify_sha256 "${_tmpinstaller}" "${NVM_SHA256}"; then
  rm -f "${_tmpinstaller}"
  exit 1
fi

w_q bash "${_tmpinstaller}"
rm -f "${_tmpinstaller}"

. "$HOME/.nvm/nvm.sh"
w_q nvm install 18
w_q nvm install 20
w_q nvm use 20
w_q nvm alias default 20

w_q npm install -g npm@latest
w_q npm install -g npm-check@latest

w_log_info "nvm module installed."
