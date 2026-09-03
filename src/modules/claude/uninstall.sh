#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# The launcher is a symlink into the versions directory removed below.
# w_remove_symlink rather than w_remove_file, so it still goes when the link is
# already dangling, which is what a half-finished uninstall leaves behind.
w_remove_symlink "$HOME/.local/bin/claude"

# Every version the install and the tool's own updates have downloaded lives
# here, and nothing else does.
w_remove_dir "$HOME/.local/share/claude"

# Removes only this module's file from env.d, never the directory itself,
# which other modules share.
w_remove_file "$HOME/.war10ck/env.d/claude"

# NOTE: ~/.claude holds credentials, project history, sessions and plugins,
# none of which war10ck created, so it is left in place.

w_log_info "claude module uninstalled."
w_log_info "Note: ~/.claude (credentials and project history) was intentionally preserved."
