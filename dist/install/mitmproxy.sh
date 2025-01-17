#!/bin/bash


URL_API_LATEST="https://api.github.com/repos/mitmproxy/mitmproxy/releases/latest"

# Fetch the latest release from GitHub API
LATEST_TAG=$(curl -s "$URL_API_LATEST" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

# Check if the fetch was successful
if [ -z "$LATEST_TAG" ]; then
    echo "[!] Failed to fetch the latest tag release"
    exit 1
fi

# Remove "v" from the tag
LATEST_TAG="${LATEST_TAG//v/}"

echo "[*] Latest tag: $LATEST_TAG"
echo "[*] Latest tag (stripped): $LATEST_TAG"

# Set download link
URL_DOWNLOAD="https://downloads.mitmproxy.org/$LATEST_TAG/mitmproxy-$LATEST_TAG-linux-x86_64.tar.gz"
curl -L -o "mitmproxy-$LATEST_TAG.tar.gz" "$URL_DOWNLOAD"

# Extract the tarball
tar -xzf "mitmproxy-$LATEST_TAG.tar.gz"

# Remove tarball
rm "mitmproxy-$LATEST_TAG.tar.gz"

# Copy binaries to $HOME/.local/bin
mkdir -p "$HOME/.local/bin"
mv mitm* "$HOME/.local/bin/"
