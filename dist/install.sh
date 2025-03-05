#!/bin/bash


URL="https://pub.thomaslaurenson.com"

IS_LOCAL=false
if [ "$IS_LOCAL" = true ]; then
    cd "$(dirname "$0")" || exit 1
    URL="."
fi

URL_PUB="$URL/pub"

# Determine fetch command
if [ "$IS_LOCAL" = true ]; then
    FETCH_CMD="_backwards_cp"
elif command -v curl &> /dev/null; then
    FETCH_CMD="curl -s -o"
elif command -v wget &> /dev/null; then
    FETCH_CMD="wget -q -O"
else
    echo "[!] No fetch command found... Exiting"
    exit 1
fi

# Define backwards_cp which switches source and destination
_backwards_cp() {
    cp "$2" "$1"
}

# Fetch and add functions file to ~/.bashrc
echo "[*] Configuring pub..."
$FETCH_CMD "pub" "$URL_PUB"

echo "[*] Setting executable permissions"
chmod +x /usr/local/bin/pub

echo "[*] Installing to path (requires sudo!)"
sudo cp pub /usr/local/bin/pub
