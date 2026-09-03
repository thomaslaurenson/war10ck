#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_sudo_remove_file "/usr/local/bin/fnm"

# Removes only this module's file from env.d, never the directory itself,
# which other modules share.
w_remove_file "$HOME/.war10ck/env.d/fnm"

# ~/.local/share/fnm holds every installed Node version and the global npm
# packages that belong to them. The install created it, so the uninstall
# removes it.
w_remove_dir "$HOME/.local/share/fnm"

w_log_info "fnm module uninstalled."
w_log_info "Note: restart your shell to clear fnm from the current session."
