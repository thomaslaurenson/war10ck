#!/bin/bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# In normal mode all noisy commands are silenced; debug mode streams full output.
_q() { if [[ "${WAR10CK_DEBUG:-0}" == "1" ]]; then "$@"; else "$@" >/dev/null 2>&1; fi; }

_q sudo apt-get install -y curl gpg

_tmpgpg=$(mktemp --suffix=-packages.microsoft.gpg)
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > "$_tmpgpg"
sudo install -D -o root -g root -m 644 "$_tmpgpg" /etc/apt/keyrings/packages.microsoft.gpg
rm -f "$_tmpgpg"

echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" | \
    sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

_q sudo apt-get install -y apt-transport-https
_q sudo apt-get update
_q sudo apt-get install -y code
