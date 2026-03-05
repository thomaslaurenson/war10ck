#!/bin/bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# In normal mode all noisy commands are silenced; debug mode streams full output.
_q() { if [[ "${WAR10CK_DEBUG:-0}" == "1" ]]; then "$@"; else "$@" >/dev/null 2>&1; fi; }

curl -fsSL https://updates.signal.org/desktop/apt/keys.asc \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null

curl -fsSL https://updates.signal.org/static/desktop/apt/signal-desktop.sources \
    | sudo tee /etc/apt/sources.list.d/signal-desktop.sources > /dev/null

_q sudo apt-get update
_q sudo apt-get install -y signal-desktop
