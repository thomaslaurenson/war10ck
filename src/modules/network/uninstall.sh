#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

readonly NM_DROPIN="/etc/NetworkManager/conf.d/10-war10ck.conf"

w_sudo_remove_file "${NM_DROPIN}"

w_remove_functions network

if systemctl is-active --quiet NetworkManager; then
  w_q sudo systemctl restart NetworkManager
fi

# network-manager itself is left installed, matching how no other module removes
# packages on uninstall, and because taking the daemon out from under a running
# desktop would strand the machine with no network stack at all.
#
# The wireless stanzas removed from /etc/network/interfaces are not restored.
# They carried a wpa-conf pointing at a hand-maintained wpa_supplicant.conf, and
# putting that back would recreate the conflict this module exists to remove.
# Saved connections live in NetworkManager's own store and are untouched here.
w_log_info "network module uninstalled."
