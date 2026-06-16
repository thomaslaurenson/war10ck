#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

WAR10CK_DIR="$HOME/.war10ck"

w_apt_install tmux

w_deploy_remote_file "modules/tmux/files/tmux.conf" "$WAR10CK_DIR/.tmux.conf"
w_deploy_remote_file "modules/tmux/files/cer"       "$WAR10CK_DIR/.tmux/cer"
w_deploy_remote_file "modules/tmux/files/home"      "$WAR10CK_DIR/.tmux/home"

w_log_info "tmux module installed."
