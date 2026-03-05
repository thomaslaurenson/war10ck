#!/bin/bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# In normal mode all noisy commands are silenced; debug mode streams full output.
_q() { if [[ "${WAR10CK_DEBUG:-0}" == "1" ]]; then "$@"; else "$@" >/dev/null 2>&1; fi; }

# Update UV_SHA256 when bumping UV_VERSION.
# To get the hash: curl -fsSL "https://astral.sh/uv/VERSION/install.sh" | sha256sum
UV_VERSION="0.10.7"
UV_SHA256="bcada2f4ddb9d0196fcf33510633a1a892b948fc0d0a8dc7650ddb67f074b6c6"

UV_INSTALLER_URL="https://astral.sh/uv/${UV_VERSION}/install.sh"

_tmpinstaller=$(mktemp --suffix=-uv-install.sh)
curl -fsSL -o "$_tmpinstaller" "$UV_INSTALLER_URL"

actual=$(sha256sum "$_tmpinstaller" | cut -d' ' -f1)
if [[ "$actual" != "$UV_SHA256" ]]; then
    echo "[!] uv installer checksum mismatch"
    echo "[!]   expected: $UV_SHA256"
    echo "[!]   actual:   $actual"
    rm -f "$_tmpinstaller"
    exit 1
fi
echo "[*] uv installer checksum OK"

_q bash "$_tmpinstaller"
rm -f "$_tmpinstaller"
