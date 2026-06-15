#!/bin/bash


URL="https://war10ck.thomaslaurenson.com"
URL_WARLOCK="$URL/war10ck"

# Determine fetch command
if command -v curl &> /dev/null; then
    FETCH_CMD="curl -s -o"
elif command -v wget &> /dev/null; then
    FETCH_CMD="wget -q -O"
else
    echo "[!] No fetch command found... Exiting"
    exit 1
fi

echo "[*] Configuring war10ck..."

echo "[*] Copying war10ck..."
$FETCH_CMD "war10ck" "$URL_WARLOCK"

echo "[*] Installing to path... (requires sudo!)"
sudo cp war10ck /usr/local/bin/war10ck

echo "[*] Setting executable permissions..."
sudo chmod +x /usr/local/bin/war10ck

echo "[*] Setting executable ownership..."
sudo chown root:root /usr/local/bin/war10ck
