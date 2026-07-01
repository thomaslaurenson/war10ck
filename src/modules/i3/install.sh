#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_install i3 i3lock dex pulseaudio-utils x11-xserver-utils brightnessctl libnotify-bin scrot gnome-keyring network-manager-gnome

w_log_info "i3 module installed."
