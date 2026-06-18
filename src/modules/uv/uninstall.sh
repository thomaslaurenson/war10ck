#!/usr/bin/env bash


set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

UV_DIR="$HOME/.war10ck/uv"

w_remove_symlink "$HOME/.config/uv/uv.toml"
w_remove_dir "$UV_DIR"
w_remove_functions uv

w_log_info "uv module uninstalled."
