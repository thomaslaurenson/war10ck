#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

ROFI_DIR="$HOME/.war10ck/rofi"

w_deploy_remote_file "modules/rofi/files/config.rasi" "$ROFI_DIR/config.rasi"

w_log_info "Rofi config installed to $ROFI_DIR"
