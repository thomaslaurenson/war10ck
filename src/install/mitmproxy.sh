#!/bin/bash

set -euo pipefail

URL_API_LATEST="https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest"

LATEST_TAG=$(curl -fsSL "$URL_API_LATEST" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [[ -z "$LATEST_TAG" ]]; then
    echo "[!] Failed to fetch the latest tag release"
    exit 1
fi
LATEST_TAG="${LATEST_TAG//v/}"
echo "[*] Latest tag (stripped): $LATEST_TAG"

ARCHIVE="mitmproxy-${LATEST_TAG}-linux-x86_64.tar.gz"
URL_DOWNLOAD="https://downloads.mitmproxy.org/${LATEST_TAG}/${ARCHIVE}"
echo "[*] Downloading: $URL_DOWNLOAD"

_tmparchive=$(mktemp --suffix=-"$ARCHIVE")
curl -fsSL -o "$_tmparchive" "$URL_DOWNLOAD"

# mitmproxy does not publish a standalone checksum file.
# Log the SHA256 of the downloaded archive for audit purposes.
ACTUAL_SHA256=$(sha256sum "$_tmparchive" | cut -d' ' -f1)
echo "[*] mitmproxy archive SHA256: $ACTUAL_SHA256"
echo "[*] Verify against: https://mitmproxy.org/downloads/"

_tmpdir=$(mktemp -d --suffix=-mitmproxy)
tar -xzf "$_tmparchive" -C "$_tmpdir"
rm -f "$_tmparchive"

sudo mv "$_tmpdir"/mitm* /usr/local/bin/
rm -rf "$_tmpdir"
