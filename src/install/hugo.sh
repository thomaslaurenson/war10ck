#!/bin/bash

set -euo pipefail

URL_API_LATEST="https://api.github.com/repos/gohugoio/hugo/releases/latest"

LATEST_TAG=$(curl -fsSL "$URL_API_LATEST" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [[ -z "$LATEST_TAG" ]]; then
    echo "[!] Failed to fetch the latest tag release"
    exit 1
fi
LATEST_TAG="${LATEST_TAG//v/}"
echo "[*] Latest tag (stripped): $LATEST_TAG"

ARCHIVE="hugo_extended_${LATEST_TAG}_linux-amd64.deb"
URL_DOWNLOAD="https://github.com/gohugoio/hugo/releases/download/v${LATEST_TAG}/${ARCHIVE}"
URL_CHECKSUMS="https://github.com/gohugoio/hugo/releases/download/v${LATEST_TAG}/hugo_${LATEST_TAG}_checksums.txt"

echo "[*] Downloading: $URL_DOWNLOAD"
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

sudo dpkg -i "$_tmpdeb"
rm -f "$_tmpdeb"
