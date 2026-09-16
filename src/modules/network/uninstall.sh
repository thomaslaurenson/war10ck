#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

readonly NM_DROPIN="/etc/NetworkManager/conf.d/10-war10ck.conf"

w_sudo_remove_file "${NM_DROPIN}"

w_remove_functions network

# Put ifupdown back in the boot path it was taken out of. It starts with nothing
# to do, because the stanzas naming the interfaces are not restored below, so
# this is about leaving the unit in its stock state rather than about handing
# any device back.
if ! systemctl is-enabled --quiet networking.service 2>/dev/null; then
  w_q sudo systemctl enable networking.service
  w_log_info "Re-enabled networking.service"
fi

if systemctl is-active --quiet NetworkManager; then
  w_q sudo systemctl restart NetworkManager
fi

# network-manager itself is left installed, matching how no other module removes
# packages on uninstall, and because taking the daemon out from under a running
# desktop would strand the machine with no network stack at all.
#
# The interface stanzas removed from /etc/network/interfaces are not restored.
# The wireless ones carried a wpa-conf pointing at a hand-maintained
# wpa_supplicant.conf, and putting that back would recreate the conflict this
# module exists to remove. The wired one was an "auto" stanza that blocks boot
# for a full DHCP timeout whenever no cable is present, so restoring it would
# hand back a defect. Saved connections live in NetworkManager's own store and
# are untouched here.
w_log_info "network module uninstalled."
