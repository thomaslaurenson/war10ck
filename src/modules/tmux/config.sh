#!/usr/bin/env bash


set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

TMUX_DIR="$HOME/.war10ck/tmux"

w_deploy_remote_file "modules/tmux/files/tmux.conf" "$TMUX_DIR/tmux.conf"
w_deploy_remote_file "modules/tmux/files/cer" "$TMUX_DIR/cer"
w_deploy_remote_file "modules/tmux/files/home" "$TMUX_DIR/home"

w_log_info "tmux config installed to $TMUX_DIR"

w_symlink "$TMUX_DIR/tmux.conf" "$HOME/.tmux.conf"
