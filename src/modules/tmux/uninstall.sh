#!/usr/bin/env bash


set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

TMUX_DIR="$HOME/.war10ck/tmux"

w_remove_symlink "$HOME/.tmux.conf"

w_remove_dir "$TMUX_DIR"

w_log_info "tmux module uninstalled."
