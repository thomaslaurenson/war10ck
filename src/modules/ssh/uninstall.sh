#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# WARNING: Do NOT remove ~/.ssh/config.d/ - this directory contains
# unmanaged host entries that are not tracked by war10ck.

w_remove_file "$HOME/.ssh/config"

# Removes only this module's file from env.d, never the directory itself,
# which other modules share.
w_remove_file "$HOME/.war10ck/env.d/ssh"

# NOTE: ssh-agent.socket is left enabled. Debian ships it with "preset: enabled",
# so disabling it here would leave the machine in a state war10ck never found it
# in rather than the one it started from.

w_log_info "SSH module uninstalled."
w_log_info "Note: ~/.ssh/config.d/ was intentionally preserved."
