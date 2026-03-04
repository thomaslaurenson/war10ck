#!/bin/bash

# shellcheck disable=SC1091

set -euo pipefail

# Update NVM_SHA256 when bumping NVM_VERSION.
# To get the hash: curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/vVERSION/install.sh" | sha256sum
NVM_VERSION="0.40.3"
NVM_SHA256="2d8359a64a3cb07c02389ad88ceecd43f2fa469c06104f92f98df5b6f315275f"

NVM_INSTALLER_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh"
echo "[*] Downloading nvm v${NVM_VERSION} installer..."

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

bash "$_tmpinstaller"
rm -f "$_tmpinstaller"

. "$HOME/.nvm/nvm.sh"
nvm install 18
nvm install 20
nvm use 20
nvm alias default 20

npm install -g npm@latest
npm install -g npm-check@latest

nvm --version
node --version
npm --version
