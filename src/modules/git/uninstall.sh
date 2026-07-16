#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_remove_functions git

w_apt_remove git

# NOTE: ~/.gitconfig is NOT removed. It carries the user's name, email, and
# signing key, which are theirs rather than war10ck's to discard.

w_log_info "git module uninstalled."
w_log_info "Note: ~/.gitconfig was intentionally preserved."
