#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Cowork runs in a QEMU VM and needs /dev/kvm, which the kvm group owns.
w_user_add_group kvm

w_log_info "claude-desktop config installed."
w_log_info "Note: log out and back in for the kvm group to take effect."
