#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Update UV_SHA256 when bumping UV_VERSION.
# To get the hash: curl -fsSL "https://astral.sh/uv/VERSION/install.sh" | sha256sum
readonly UV_VERSION="0.13.9"
readonly UV_SHA256="ccc888115ac831bd9c30855c1d4abeae32fce679701d2aac8e72eb0beffb41c2"

readonly UV_INSTALLER_URL="https://astral.sh/uv/${UV_VERSION}/install.sh"

_tmpinstaller=$(mktemp --suffix=-uv-install.sh)
w_download "${UV_INSTALLER_URL}" "${_tmpinstaller}"

if ! w_verify_sha256 "${_tmpinstaller}" "${UV_SHA256}"; then
  rm -f "${_tmpinstaller}"
  exit 1
fi

w_q bash "${_tmpinstaller}"
rm -f "${_tmpinstaller}"

w_log_info "uv module installed."
