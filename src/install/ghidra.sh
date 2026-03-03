#!/bin/bash


sudo rm -rf /opt/ghidra*

GHIDRA_API_URL="https://api.github.com/repos/NationalSecurityAgency/ghidra"
GHIDRA_DOWNLOAD_URL=$(curl -s "$GHIDRA_API_URL/releases/latest" | grep "browser_download_url" | grep ".zip" | cut -d '"' -f 4)

sudo rm -rf /opt/ghidra
wget "$GHIDRA_DOWNLOAD_URL" -O ghidra.zip
sudo unzip ghidra.zip -d /opt/
sudo rm ghidra.zip

GHIDRA_DIR=$(find /opt -maxdepth 1 -type d -name "ghidra_*_PUBLIC" | sort | tail -n 1)

sudo ln -sf "$GHIDRA_DIR/ghidraRun" /usr/local/bin/ghidra
sudo chmod +x "$GHIDRA_DIR/ghidraRun"
