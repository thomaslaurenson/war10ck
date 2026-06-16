#!/usr/bin/env bash


set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

ALACRITTY_DIR="$HOME/.war10ck/alacritty"

# Remove the symlink in ~/.config
w_remove_symlink "$HOME/.config/alacritty/alacritty.toml"

# Remove the deployed config directory
w_remove_dir "$ALACRITTY_DIR"

w_log_info "Alacritty module uninstalled."
