#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

LATEST_TAG=$(w_github_latest_tag "gohugoio/hugo")

ARCHIVE="hugo_extended_${LATEST_TAG}_linux-amd64.deb"
URL_DOWNLOAD="https://github.com/gohugoio/hugo/releases/download/v${LATEST_TAG}/${ARCHIVE}"
URL_CHECKSUMS="https://github.com/gohugoio/hugo/releases/download/v${LATEST_TAG}/hugo_${LATEST_TAG}_checksums.txt"

_tmpdeb=$(mktemp --suffix=-"$ARCHIVE")
curl -fsSL -o "$_tmpdeb" "$URL_DOWNLOAD"

if ! w_github_checksums_verify "$_tmpdeb" "$ARCHIVE" "$URL_CHECKSUMS"; then
    rm -f "$_tmpdeb"
    exit 1
fi

w_q sudo dpkg -i "$_tmpdeb"
rm -f "$_tmpdeb"

w_log_info "hugo module installed."
