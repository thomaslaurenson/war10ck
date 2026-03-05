#!/bin/bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# In normal mode all noisy commands are silenced; debug mode streams full output.
_q() { if [[ "${WAR10CK_DEBUG:-0}" == "1" ]]; then "$@"; else "$@" >/dev/null 2>&1; fi; }

URL_API_LATEST="https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest"

LATEST_TAG=$(curl -fsSL "$URL_API_LATEST" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [[ -z "$LATEST_TAG" ]]; then
    echo "[!] Failed to fetch the latest mitmproxy release tag"
    exit 1
fi
LATEST_TAG="${LATEST_TAG//v/}"

ARCHIVE="mitmproxy-${LATEST_TAG}-linux-x86_64.tar.gz"
URL_DOWNLOAD="https://downloads.mitmproxy.org/${LATEST_TAG}/${ARCHIVE}"

_tmparchive=$(mktemp --suffix=-"$ARCHIVE")
curl -fsSL -o "$_tmparchive" "$URL_DOWNLOAD"

# mitmproxy does not publish a standalone checksum file.
# Print the SHA256 of the downloaded archive for manual audit.
echo "[*] mitmproxy archive SHA256: $(sha256sum "$_tmparchive" | cut -d' ' -f1)"
echo "[*] Verify against: https://mitmproxy.org/downloads/"

_tmpdir=$(mktemp -d --suffix=-mitmproxy)
_q tar -xzf "$_tmparchive" -C "$_tmpdir"
rm -f "$_tmparchive"

sudo mv "$_tmpdir"/mitm* /usr/local/bin/
rm -rf "$_tmpdir"
