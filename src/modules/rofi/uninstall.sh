#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_remove rofi
w_remove_dir "$HOME/.war10ck/rofi"
