#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

POLYBAR_DIR="$HOME/.war10ck/polybar"

w_deploy_remote_file "modules/polybar/files/config.ini"              "$POLYBAR_DIR/config.ini"
w_deploy_remote_file "modules/polybar/files/launch.sh"               "$POLYBAR_DIR/launch.sh"
w_deploy_remote_file "modules/polybar/files/workspaces.sh"            "$POLYBAR_DIR/workspaces.sh"
w_make_executable "$POLYBAR_DIR/launch.sh"
w_make_executable "$POLYBAR_DIR/workspaces.sh"

w_log_info "Polybar config installed to $POLYBAR_DIR"
