#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_install i3 i3lock xss-lock dex network-manager-gnome pulseaudio-utils x11-xserver-utils

w_log_info "i3 module installed."
