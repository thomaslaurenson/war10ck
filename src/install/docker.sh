#!/bin/bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# In normal mode all noisy commands are silenced; debug mode streams full output.
_q() { if [[ "${WAR10CK_DEBUG:-0}" == "1" ]]; then "$@"; else "$@" >/dev/null 2>&1; fi; }

# Remove any conflicting packages (allowed to fail if not installed)
sudo apt-get remove docker docker-engine docker.io containerd runc 2>/dev/null || true

# Add GPG key
_q sudo apt-get update
_q sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add repo to apt
# shellcheck disable=SC1091
echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
_q sudo apt-get update

# Install
_q sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Add executing user to group
sudo usermod -aG docker "$USER"
