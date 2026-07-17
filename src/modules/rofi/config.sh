#!/usr/bin/env bash


set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

ROFI_DIR="$HOME/.war10ck/rofi"

w_deploy_remote_file "modules/rofi/files/config.rasi" "$ROFI_DIR/config.rasi"
w_deploy_remote_file "modules/rofi/files/launch.sh" "$ROFI_DIR/launch.sh"
w_deploy_remote_file "modules/rofi/files/run.sh" "$ROFI_DIR/run.sh"
w_deploy_remote_file "modules/rofi/files/i3-cheatsheet.sh" "$ROFI_DIR/i3-cheatsheet.sh"
w_make_executable "$ROFI_DIR/launch.sh"
w_make_executable "$ROFI_DIR/run.sh"
w_make_executable "$ROFI_DIR/i3-cheatsheet.sh"

w_log_info "rofi config installed to $ROFI_DIR"
