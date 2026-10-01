#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Update UV_SHA256 when bumping UV_VERSION.
# To get the hash: curl -fsSL "https://astral.sh/uv/VERSION/install.sh" | sha256sum
readonly UV_VERSION="0.12.21"
readonly UV_SHA256="0722d6c438395e39e1c27a86a79054d3b2820dd9399c7f8b0f6f84cd27ce36c3"

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
