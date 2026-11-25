#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_remove claude-desktop

w_apt_remove_source "claude-desktop"
w_apt_remove_key "claude-desktop"

# The package writes its own copy of the key on every install, and keeps it on
# remove while a source it did not write still names the repository. That
# source only goes after the package, above, so the copy is removed here.
w_sudo_remove_file "/usr/share/keyrings/claude-desktop-archive-keyring.asc"

# Reverses the group membership added by claude-desktop/config.sh.
w_user_remove_group kvm

# NOTE: ~/.config/Claude holds app settings and session data that war10ck did
# not create, so it is left in place. The sign-in lives in the desktop keyring.

w_log_info "claude-desktop module uninstalled."
w_log_info "Note: ~/.config/Claude was intentionally preserved."
