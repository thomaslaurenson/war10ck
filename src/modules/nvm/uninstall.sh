#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# The nvm installer appends its own lines to ~/.bashrc rather than confining
# them to a war10ck-managed block, so they have to be matched directly.
w_remove_lines "$HOME/.bashrc" 'NVM_DIR'

# ~/.nvm holds the nvm runtime, every installed Node version, and all globally
# installed npm packages. The install created it, so the uninstall removes it.
w_remove_dir "$HOME/.nvm"

w_log_info "nvm module uninstalled."
w_log_info "Note: restart your shell to clear nvm from the current session."
