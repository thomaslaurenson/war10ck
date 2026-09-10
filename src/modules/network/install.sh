#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# NetworkManager usually arrives as a dependency of network-manager-gnome, which
# the i3 module installs for the tray applet. Naming the daemon here makes the
# dependency deliberate, so the network stack does not disappear if i3 is
# uninstalled or the desktop is swapped for something else.
w_apt_install network-manager

w_log_info "network module installed."
