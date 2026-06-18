#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

LATEST_TAG=$(w_github_latest_tag "ankitpokhrel/jira-cli")

ARCHIVE="jira_${LATEST_TAG}_linux_x86_64.tar.gz"
URL_DOWNLOAD="https://github.com/ankitpokhrel/jira-cli/releases/download/v${LATEST_TAG}/${ARCHIVE}"
URL_CHECKSUMS="https://github.com/ankitpokhrel/jira-cli/releases/download/v${LATEST_TAG}/checksums.txt"

_tmparchive=$(mktemp --suffix=-"$ARCHIVE")
curl -fsSL -o "$_tmparchive" "$URL_DOWNLOAD"

if ! w_github_checksums_verify "$_tmparchive" "$ARCHIVE" "$URL_CHECKSUMS"; then
    rm -f "$_tmparchive"
    exit 1
fi

_tmpdir=$(mktemp -d --suffix=-jira)
w_q tar -xzf "$_tmparchive" -C "$_tmpdir"
rm -f "$_tmparchive"

# The archive extracts into a versioned subdirectory; locate the binary dynamically.
_jira_bin=$(find "$_tmpdir" -type f -name "jira" | head -1)
if [[ -z "$_jira_bin" ]]; then
    w_log_error "Could not locate jira binary in extracted archive"
    rm -rf "$_tmpdir"
    exit 1
fi
sudo mv "$_jira_bin" /usr/local/bin/jira
rm -rf "$_tmpdir"

w_log_info "jira module installed."
