#!/bin/bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# In normal mode all noisy commands are silenced; debug mode streams full output.
_q() { if [[ "${WAR10CK_DEBUG:-0}" == "1" ]]; then "$@"; else "$@" >/dev/null 2>&1; fi; }

URL_API_LATEST="https://api.github.com/repos/ankitpokhrel/jira-cli/releases/latest"

LATEST_TAG=$(curl -fsSL "$URL_API_LATEST" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [[ -z "$LATEST_TAG" ]]; then
    echo "[!] Failed to fetch the latest tag release"
    exit 1
fi
LATEST_TAG="${LATEST_TAG//v/}"

ARCHIVE="jira_${LATEST_TAG}_linux_x86_64.tar.gz"
URL_DOWNLOAD="https://github.com/ankitpokhrel/jira-cli/releases/download/v${LATEST_TAG}/${ARCHIVE}"
URL_CHECKSUMS="https://github.com/ankitpokhrel/jira-cli/releases/download/v${LATEST_TAG}/checksums.txt"

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
_q tar -xzf "$_tmparchive" -C "$_tmpdir"
rm -f "$_tmparchive"

# The archive extracts into a versioned subdirectory; locate the binary dynamically.
_jira_bin=$(find "$_tmpdir" -type f -name "jira" | head -1)
if [[ -z "$_jira_bin" ]]; then
    echo "[!] Could not locate jira binary in extracted archive"
    rm -rf "$_tmpdir"
    exit 1
fi
sudo mv "$_jira_bin" /usr/local/bin/jira
rm -rf "$_tmpdir"
