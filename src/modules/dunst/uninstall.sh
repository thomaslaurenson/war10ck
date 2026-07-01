#!/usr/bin/env bash


set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

DUNST_DIR="$HOME/.war10ck/dunst"

# Remove the symlink in ~/.config
w_remove_symlink "$HOME/.config/dunst/dunstrc"

# Remove the deployed config directory
w_remove_dir "$DUNST_DIR"

w_log_info "dunst module uninstalled."
