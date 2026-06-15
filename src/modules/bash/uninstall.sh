#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# WARNING: Do NOT remove ~/.war10ck/bashrc.d/ - this directory contains
# unmanaged scripts that are sourced at shell startup. It is intentionally
# left unmanaged by war10ck and must be preserved across uninstalls.

w_remove_file "$HOME/.war10ck/.aliases"
w_remove_file "$HOME/.war10ck/.environment"
w_remove_file "$HOME/.war10ck/.history"
w_remove_file "$HOME/.war10ck/.rundmc"
w_remove_dir  "$HOME/.war10ck/functions.d"

w_log_info "Bash module uninstalled."
w_log_info "Note: ~/.war10ck/bashrc.d/ was intentionally preserved."
