#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

BTOP_DIR="$HOME/.war10ck/btop"

w_remove_symlink "$HOME/.config/btop/btop.conf"
w_remove_symlink "$HOME/.config/btop/themes/war10ck.theme"
w_remove_dir "$BTOP_DIR"
w_apt_remove btop

w_log_info "btop module uninstalled."
