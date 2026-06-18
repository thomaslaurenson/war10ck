#!/usr/bin/env bash


set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

ALACRITTY_DIR="$HOME/.war10ck/alacritty"

_alacritty_version_gte() {
    # Returns 0 if installed version >= $1
    local minimum="$1"
    local installed
    installed=$(alacritty --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "0.0.0")
    printf '%s\n%s\n' "$minimum" "$installed" | sort -V -C
}

if _alacritty_version_gte "0.13.0"; then
    w_deploy_remote_file "modules/alacritty/files/alacritty.toml" "$ALACRITTY_DIR/alacritty.toml"
    w_log_info "Alacritty config installed to $ALACRITTY_DIR (toml)"
    w_symlink "$ALACRITTY_DIR/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
else
    w_deploy_remote_file "modules/alacritty/files/alacritty.yml" "$ALACRITTY_DIR/alacritty.yml"
    w_log_info "Alacritty config installed to $ALACRITTY_DIR (yaml)"
    w_symlink "$ALACRITTY_DIR/alacritty.yml" "$HOME/.config/alacritty/alacritty.yml"
fi
