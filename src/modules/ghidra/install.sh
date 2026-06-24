#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_install openjdk-21-jdk unzip

GHIDRA_API_URL="https://api.github.com/repos/NationalSecurityAgency/ghidra"

# Fetch latest release metadata once - Ghidra embeds the SHA256 in the release
# body rather than publishing a checksums file, so we need the full JSON.
RELEASE_JSON=$(curl -fsSL "$GHIDRA_API_URL/releases/latest")

# Use two-stage grep to avoid variable-length lookbehind (not supported by GNU grep).
GHIDRA_DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep "browser_download_url" | grep "\.zip" | cut -d '"' -f 4)
GHIDRA_SHA256=$(echo "$RELEASE_JSON" | grep -i 'sha.256' | grep -oE '[a-f0-9]{64}' | head -1)

if [[ -z "$GHIDRA_DOWNLOAD_URL" ]]; then
    w_log_error "Failed to resolve Ghidra download URL"
    exit 1
fi
if [[ -z "$GHIDRA_SHA256" ]]; then
    w_log_error "Failed to parse Ghidra SHA256 from release notes"
    exit 1
fi

_tmpzip=$(mktemp --suffix=-ghidra.zip)
w_q curl -fsSL -o "$_tmpzip" "$GHIDRA_DOWNLOAD_URL"

if ! w_verify_sha256 "$_tmpzip" "$GHIDRA_SHA256"; then
    rm -f "$_tmpzip"
    exit 1
fi

sudo rm -rf /opt/ghidra*
w_q sudo unzip -q "$_tmpzip" -d /opt/
rm -f "$_tmpzip"

GHIDRA_DIR=$(find /opt -maxdepth 1 -type d -name "ghidra_*_PUBLIC*" | sort | tail -n 1)
sudo ln -sf "$GHIDRA_DIR/ghidraRun" /usr/local/bin/ghidra
sudo chmod +x "$GHIDRA_DIR/ghidraRun"

w_log_info "ghidra module installed."
