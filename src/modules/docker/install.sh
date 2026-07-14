#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_remove docker docker-engine docker.io containerd runc

w_apt_install ca-certificates curl gnupg
# shellcheck disable=SC1091
DISTRO_ID=$(. /etc/os-release && echo "$ID")
# shellcheck disable=SC1091
DISTRO_CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
w_apt_add_key "docker" "https://download.docker.com/linux/${DISTRO_ID}/gpg"
w_apt_add_source "docker" "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRO_ID} ${DISTRO_CODENAME} stable"

w_apt_install \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

w_log_info "docker module installed."
