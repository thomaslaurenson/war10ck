#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_sudo_remove_dir "/opt/mpqeditor"
w_remove_file "$HOME/.local/share/applications/mpqeditor.desktop"

w_log_info "mpqeditor module uninstalled."
