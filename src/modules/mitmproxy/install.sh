#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

LATEST_TAG=$(w_github_latest_tag "mitmproxy/mitmproxy")

ARCHIVE="mitmproxy-${LATEST_TAG}-linux-x86_64.tar.gz"
URL_DOWNLOAD="https://downloads.mitmproxy.org/${LATEST_TAG}/${ARCHIVE}"

_tmparchive=$(mktemp --suffix=-"$ARCHIVE")
curl -fsSL -o "$_tmparchive" "$URL_DOWNLOAD"

# mitmproxy does not publish a standalone checksum file.
w_log_info "mitmproxy archive SHA256: $(sha256sum "$_tmparchive" | cut -d' ' -f1)"
w_log_info "Verify against: https://mitmproxy.org/downloads/"

_tmpdir=$(mktemp -d --suffix=-mitmproxy)
w_q tar -xzf "$_tmparchive" -C "$_tmpdir"
rm -f "$_tmparchive"

sudo mv "$_tmpdir"/mitm* /usr/local/bin/
rm -rf "$_tmpdir"

w_log_info "mitmproxy module installed."
