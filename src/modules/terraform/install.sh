#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_install gnupg software-properties-common
w_apt_add_key "hashicorp" "https://apt.releases.hashicorp.com/gpg"
w_apt_add_source "hashicorp" "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
w_apt_install terraform

w_log_info "terraform module installed."
