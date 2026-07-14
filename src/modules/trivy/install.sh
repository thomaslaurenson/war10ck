#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

LATEST_TAG=$(w_github_latest_tag "aquasecurity/trivy")

ARCHIVE="trivy_${LATEST_TAG}_Linux-64bit.deb"
URL_DOWNLOAD="https://github.com/aquasecurity/trivy/releases/download/v${LATEST_TAG}/${ARCHIVE}"
URL_CHECKSUMS="https://github.com/aquasecurity/trivy/releases/download/v${LATEST_TAG}/trivy_${LATEST_TAG}_checksums.txt"

_tmpdeb=$(mktemp --suffix=-"$ARCHIVE")
curl -fsSL -o "$_tmpdeb" "$URL_DOWNLOAD"

if ! w_github_checksums_verify "$_tmpdeb" "$ARCHIVE" "$URL_CHECKSUMS"; then
    rm -f "$_tmpdeb"
    exit 1
fi

w_q sudo dpkg -i "$_tmpdeb"
rm -f "$_tmpdeb"

w_log_info "trivy module installed."
