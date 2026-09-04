#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# The launcher is checked by path as well as by name: the claude module puts
# ~/.local/bin on PATH through env.d, and that only reaches shells started
# after it was applied, so a machine that has just had both modules applied in
# one run does not yet see claude on PATH.
if [[ ! -e "${HOME}/.local/bin/claude" ]] && ! w_is_installed claude; then
  w_log_error "claude is not installed. Apply the claude module first."
  exit 1
fi

w_log_info "clap module installed."
