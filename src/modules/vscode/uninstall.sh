#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_remove code

w_apt_remove_source "packages.microsoft"
w_apt_remove_key "packages.microsoft"

# NOTE: ~/.config/Code and ~/.vscode hold user settings and extensions that
# war10ck did not create, so they are left untouched.

w_log_info "vscode module uninstalled."
w_log_info "Note: ~/.config/Code and ~/.vscode were intentionally preserved."
