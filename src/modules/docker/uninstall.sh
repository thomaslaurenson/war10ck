#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_remove \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

w_apt_remove_source "docker"
w_apt_remove_key "docker"

# Reverses the group membership added by docker/config.sh.
w_user_remove_group docker

# NOTE: /var/lib/docker is left in place. It holds images, volumes, and
# container state that war10ck did not create and cannot safely discard.

w_log_info "docker module uninstalled."
w_log_info "Note: /var/lib/docker (images and volumes) was intentionally preserved."
