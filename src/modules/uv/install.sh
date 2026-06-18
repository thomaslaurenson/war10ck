#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Update UV_SHA256 when bumping UV_VERSION.
# To get the hash: curl -fsSL "https://astral.sh/uv/VERSION/install.sh" | sha256sum
UV_VERSION="0.11.21"
UV_SHA256="053045e1e69ec77358fd44f2ef2cacb768a22d50f433e213624f0157ffbbc883"

UV_INSTALLER_URL="https://astral.sh/uv/${UV_VERSION}/install.sh"

_tmpinstaller=$(mktemp --suffix=-uv-install.sh)
curl -fsSL -o "$_tmpinstaller" "$UV_INSTALLER_URL"

if ! w_verify_sha256 "$_tmpinstaller" "$UV_SHA256"; then
    rm -f "$_tmpinstaller"
    exit 1
fi

w_q bash "$_tmpinstaller"
rm -f "$_tmpinstaller"

w_log_info "uv module installed."
