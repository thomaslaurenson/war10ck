#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_remove packer

w_log_info "packer module uninstalled."
