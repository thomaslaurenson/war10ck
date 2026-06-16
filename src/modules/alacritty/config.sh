#!/usr/bin/env bash


set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

ALACRITTY_DIR="$HOME/.war10ck/alacritty"

w_deploy_remote_file "modules/alacritty/files/alacritty.toml" "$ALACRITTY_DIR/alacritty.toml"

w_log_info "Alacritty config installed to $ALACRITTY_DIR"
w_symlink "$ALACRITTY_DIR/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
