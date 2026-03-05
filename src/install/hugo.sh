#!/bin/bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# In normal mode all noisy commands are silenced; debug mode streams full output.
_q() { if [[ "${WAR10CK_DEBUG:-0}" == "1" ]]; then "$@"; else "$@" >/dev/null 2>&1; fi; }

URL_API_LATEST="https://api.github.com/repos/gohugoio/hugo/releases/latest"

LATEST_TAG=$(curl -fsSL "$URL_API_LATEST" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [[ -z "$LATEST_TAG" ]]; then
    echo "[!] Failed to fetch the latest Hugo release tag"
    exit 1
fi
LATEST_TAG="${LATEST_TAG//v/}"

ARCHIVE="hugo_extended_${LATEST_TAG}_linux-amd64.deb"
URL_DOWNLOAD="https://github.com/gohugoio/hugo/releases/download/v${LATEST_TAG}/${ARCHIVE}"
URL_CHECKSUMS="https://github.com/gohugoio/hugo/releases/download/v${LATEST_TAG}/hugo_${LATEST_TAG}_checksums.txt"

_tmpdeb=$(mktemp --suffix=-"$ARCHIVE")
_tmpchecksums=$(mktemp --suffix=-hugo-checksums.txt)
curl -fsSL -o "$_tmpdeb" "$URL_DOWNLOAD"
curl -fsSL -o "$_tmpchecksums" "$URL_CHECKSUMS"

expected=$(grep "$ARCHIVE" "$_tmpchecksums" | cut -d' ' -f1)
if [[ -z "$expected" ]]; then
    echo "[!] No checksum entry found for $ARCHIVE in checksums.txt"
    rm -f "$_tmpdeb" "$_tmpchecksums"
    exit 1
fi

actual=$(sha256sum "$_tmpdeb" | cut -d' ' -f1)
if [[ "$actual" != "$expected" ]]; then
    echo "[!] Hugo package checksum mismatch"
    echo "[!]   expected: $expected"
    echo "[!]   actual:   $actual"
    rm -f "$_tmpdeb" "$_tmpchecksums"
    exit 1
fi
echo "[*] Hugo package checksum OK"
rm -f "$_tmpchecksums"

_q sudo dpkg -i "$_tmpdeb"
rm -f "$_tmpdeb"
