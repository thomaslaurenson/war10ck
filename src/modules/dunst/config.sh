#!/usr/bin/env bash


set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

DUNST_DIR="$HOME/.war10ck/dunst"

w_deploy_remote_file "modules/dunst/files/dunstrc" "$DUNST_DIR/dunstrc"
w_log_info "dunst config installed to $DUNST_DIR"

w_symlink "$DUNST_DIR/dunstrc" "$HOME/.config/dunst/dunstrc"
