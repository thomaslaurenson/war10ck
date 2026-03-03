#!/bin/bash


URL_API_LATEST="https://api.github.com/repos/astral-sh/uv/releases/latest"

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

curl -LsSf https://astral.sh/uv/"$LATEST_TAG"/install.sh | sh

uv self version
