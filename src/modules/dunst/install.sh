#!/usr/bin/env bash


set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_install dunst gnome-icon-theme

w_log_info "dunst module installed."
