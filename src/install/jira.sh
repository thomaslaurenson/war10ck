#!/bin/bash

set -euo pipefail

URL_API_LATEST="https://api.github.com/repos/ankitpokhrel/jira-cli/releases/latest"

LATEST_TAG=$(curl -fsSL "$URL_API_LATEST" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [[ -z "$LATEST_TAG" ]]; then
    echo "[!] Failed to fetch the latest tag release"
    exit 1
fi
LATEST_TAG="${LATEST_TAG//v/}"
echo "[*] Latest tag (stripped): $LATEST_TAG"

ARCHIVE="jira_${LATEST_TAG}_linux_x86_64.tar.gz"
URL_DOWNLOAD="https://github.com/ankitpokhrel/jira-cli/releases/download/v${LATEST_TAG}/${ARCHIVE}"
URL_CHECKSUMS="https://github.com/ankitpokhrel/jira-cli/releases/download/v${LATEST_TAG}/checksums.txt"

echo "[*] Downloading: $URL_DOWNLOAD"
_tmparchive=$(mktemp --suffix=-"$ARCHIVE")
_tmpchecksums=$(mktemp --suffix=-jira-checksums.txt)
curl -fsSL -o "$_tmparchive" "$URL_DOWNLOAD"
curl -fsSL -o "$_tmpchecksums" "$URL_CHECKSUMS"

expected=$(grep "$ARCHIVE" "$_tmpchecksums" | cut -d' ' -f1)
if [[ -z "$expected" ]]; then
    echo "[!] No checksum entry found for $ARCHIVE in checksums.txt"
    rm -f "$_tmparchive" "$_tmpchecksums"
    exit 1
fi

actual=$(sha256sum "$_tmparchive" | cut -d' ' -f1)
if [[ "$actual" != "$expected" ]]; then
    echo "[!] Jira CLI archive checksum mismatch"
    echo "[!]   expected: $expected"
    echo "[!]   actual:   $actual"
    rm -f "$_tmparchive" "$_tmpchecksums"
    exit 1
fi
echo "[*] Jira CLI archive checksum OK"
rm -f "$_tmpchecksums"

_tmpdir=$(mktemp -d --suffix=-jira)
tar -xzf "$_tmparchive" -C "$_tmpdir"
rm -f "$_tmparchive"

sudo mv "$_tmpdir/bin/jira" /usr/local/bin/jira
rm -rf "$_tmpdir"
