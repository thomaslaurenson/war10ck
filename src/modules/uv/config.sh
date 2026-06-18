#!/usr/bin/env bash


set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

UV_DIR="$HOME/.war10ck/uv"

w_deploy_remote_file "modules/uv/files/uv.toml" "$UV_DIR/uv.toml"
w_deploy_functions uv

w_log_info "uv config installed to $UV_DIR"
w_symlink "$UV_DIR/uv.toml" "$HOME/.config/uv/uv.toml"
