#!/bin/bash

# shellcheck disable=SC1091

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# In normal mode all noisy commands are silenced; debug mode streams full output.
_q() { if [[ "${WAR10CK_DEBUG:-0}" == "1" ]]; then "$@"; else "$@" >/dev/null 2>&1; fi; }

# Update NVM_SHA256 when bumping NVM_VERSION.
# To get the hash: curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/vVERSION/install.sh" | sha256sum
NVM_VERSION="0.40.3"
NVM_SHA256="2d8359a64a3cb07c02389ad88ceecd43f2fa469c06104f92f98df5b6f315275f"

NVM_INSTALLER_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh"

_tmpinstaller=$(mktemp --suffix=-nvm-install.sh)
curl -fsSL -o "$_tmpinstaller" "$NVM_INSTALLER_URL"

actual=$(sha256sum "$_tmpinstaller" | cut -d' ' -f1)
if [[ "$actual" != "$NVM_SHA256" ]]; then
    echo "[!] nvm installer checksum mismatch"
    echo "[!]   expected: $NVM_SHA256"
    echo "[!]   actual:   $actual"
    rm -f "$_tmpinstaller"
    exit 1
fi
echo "[*] nvm installer checksum OK"

_q bash "$_tmpinstaller"
rm -f "$_tmpinstaller"

. "$HOME/.nvm/nvm.sh"
_q nvm install 18
_q nvm install 20
_q nvm use 20
_q nvm alias default 20

_q npm install -g npm@latest
_q npm install -g npm-check@latest
