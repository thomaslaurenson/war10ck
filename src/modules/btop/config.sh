#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

BTOP_DIR="$HOME/.war10ck/btop"

w_deploy_remote_file "modules/btop/files/btop.conf" "$BTOP_DIR/btop.conf"
w_deploy_remote_file "modules/btop/files/war10ck.theme" "$BTOP_DIR/war10ck.theme"
w_log_info "btop config installed to $BTOP_DIR"

w_symlink "$BTOP_DIR/btop.conf" "$HOME/.config/btop/btop.conf"
w_symlink "$BTOP_DIR/war10ck.theme" "$HOME/.config/btop/themes/war10ck.theme"
