#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_install openssh-client sshfs

# The socket unit is what gives a headless login an agent: over SSH nothing else
# starts one, so AddKeysToAgent has nowhere to put a key. A graphical session
# starts an agent of its own, and the env.d fragment leaves that one alone.
#
# Skipped rather than failed where there is no systemd user session, since a
# container or a CI run has no user bus for systemctl --user to reach.
if [[ -d /run/systemd/system && -n "${XDG_RUNTIME_DIR:-}" ]]; then
  if w_q systemctl --user enable --now ssh-agent.socket; then
    w_log_info "ssh-agent socket enabled."
  else
    w_log_error "Could not enable ssh-agent.socket, check: systemctl --user status ssh-agent.socket"
  fi
else
  w_log_info "No systemd user session, skipping ssh-agent socket activation."
fi

w_log_info "ssh module installed."
