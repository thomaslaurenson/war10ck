#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Update UV_SHA256 when bumping UV_VERSION.
# To get the hash: curl -fsSL "https://astral.sh/uv/VERSION/install.sh" | sha256sum
readonly UV_VERSION="0.13.5"
readonly UV_SHA256="1c6e7f025499664633ac2dce43a210800510e9ef0625c52e034a8afdf8bf177a"

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
