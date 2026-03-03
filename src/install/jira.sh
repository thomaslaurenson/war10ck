#!/bin/bash


URL_API_LATEST="https://api.github.com/repos/ankitpokhrel/jira-cli/releases/latest"

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
URL_DOWNLOAD="https://github.com/ankitpokhrel/jira-cli/releases/download/v$LATEST_TAG/jira_${LATEST_TAG}_linux_x86_64.tar.gz"

echo "[*] Downloading from: $URL_DOWNLOAD"

curl -L -o "jira_${LATEST_TAG}_linux_x86_64.tar.gz" "$URL_DOWNLOAD"

# Extract the downloaded tar.gz file
tar -xvzf "jira_${LATEST_TAG}_linux_x86_64.tar.gz"

# Move the binary to /usr/local/bin
sudo mv "jira_${LATEST_TAG}_linux_x86_64/bin/jira" /usr/local/bin/jira

# Clean up the downloaded files
rm "jira_${LATEST_TAG}_linux_x86_64.tar.gz"
rm -rf "jira_${LATEST_TAG}_linux_x86_64"
