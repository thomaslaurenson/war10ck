#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_remove_functions clap

# NOTE: ~/.claude.d holds each profile's credentials, history and projects.
# clap created those directories, but nothing inside them is war10ck's to
# remove, so they are left in place.

w_log_info "clap module uninstalled."
w_log_info "Note: ~/.claude.d (profile credentials and history) was intentionally preserved."
