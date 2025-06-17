#!/bin/bash


URL_API_LATEST="https://api.github.com/repos/gohugoio/hugo/releases/latest"

# Fetch the latest release from GitHub API
LATEST_TAG=$(curl -s "$URL_API_LATEST" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

# Check if the fetch was successful
if [ -z "$LATEST_TAG" ]; then
    echo "[!] Failed to fetch the latest tag release"
    exit 1
fi

# Remove "v" from the tag
LATEST_TAG="${LATEST_TAG//v/}"

echo "[*] Latest tag (stripped): $LATEST_TAG"

# Set download link
URL_DOWNLOAD="https://github.com/gohugoio/hugo/releases/download/v$LATEST_TAG/hugo_extended_${LATEST_TAG}_linux-amd64.deb"
curl -L -o "hugo_extended_${LATEST_TAG}_linux-amd64.deb" "$URL_DOWNLOAD"

# Install the downloaded .deb package
sudo dpkg -i "hugo_extended_${LATEST_TAG}_linux-amd64.deb"

# Clean up the downloaded file
rm "hugo_extended_${LATEST_TAG}_linux-amd64.deb"
