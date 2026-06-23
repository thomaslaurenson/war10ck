#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_install \
    jq \
    make \
    shellcheck

w_log_info "utilities module installed."
