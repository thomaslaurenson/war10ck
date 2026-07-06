#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_remove terraform

w_log_info "terraform module uninstalled."
