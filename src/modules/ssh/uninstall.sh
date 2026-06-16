#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# WARNING: Do NOT remove ~/.ssh/config.d/ - this directory contains
# unmanaged host entries that are not tracked by war10ck.

w_remove_file "$HOME/.ssh/config"

w_log_info "SSH module uninstalled."
w_log_info "Note: ~/.ssh/config.d/ was intentionally preserved."
