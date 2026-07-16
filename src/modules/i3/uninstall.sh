#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_remove_symlink "$HOME/.config/i3/config"
w_remove_dir "$HOME/.war10ck/i3"

w_log_info "i3 module uninstalled."
