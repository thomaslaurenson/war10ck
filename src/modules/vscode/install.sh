#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_install curl gpg apt-transport-https
w_apt_add_key "packages.microsoft" "https://packages.microsoft.com/keys/microsoft.asc"
w_apt_add_source "packages.microsoft" "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main"
w_apt_install code

w_log_info "vscode module installed."
