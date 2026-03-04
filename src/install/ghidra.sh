#!/bin/bash

set -euo pipefail

GHIDRA_API_URL="https://api.github.com/repos/NationalSecurityAgency/ghidra"

# Fetch latest release metadata once
RELEASE_JSON=$(curl -fsSL "$GHIDRA_API_URL/releases/latest")

# Extract download URL and expected SHA256 from the release body
GHIDRA_DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep "browser_download_url" | grep "\.zip" | cut -d '"' -f 4)
GHIDRA_SHA256=$(echo "$RELEASE_JSON" | grep -oP '(?<=SHA-256[: \`]+)[a-f0-9]{64}' | head -1)

if [[ -z "$GHIDRA_DOWNLOAD_URL" ]]; then
    echo "[!] Failed to resolve Ghidra download URL"
    exit 1
fi
if [[ -z "$GHIDRA_SHA256" ]]; then
    echo "[!] Failed to parse Ghidra SHA256 from release notes"
    exit 1
fi

echo "[*] Downloading: $GHIDRA_DOWNLOAD_URL"
_tmpzip=$(mktemp --suffix=-ghidra.zip)
wget -q "$GHIDRA_DOWNLOAD_URL" -O "$_tmpzip"

actual=$(sha256sum "$_tmpzip" | cut -d' ' -f1)
if [[ "$actual" != "$GHIDRA_SHA256" ]]; then
    echo "[!] Ghidra archive checksum mismatch"
    echo "[!]   expected: $GHIDRA_SHA256"
    echo "[!]   actual:   $actual"
    rm -f "$_tmpzip"
    exit 1
fi
echo "[*] Ghidra archive checksum OK"

sudo rm -rf /opt/ghidra*
sudo unzip -q "$_tmpzip" -d /opt/
rm -f "$_tmpzip"

GHIDRA_DIR=$(find /opt -maxdepth 1 -type d -name "ghidra_*_PUBLIC" | sort | tail -n 1)
sudo ln -sf "$GHIDRA_DIR/ghidraRun" /usr/local/bin/ghidra
sudo chmod +x "$GHIDRA_DIR/ghidraRun"
