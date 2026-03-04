#!/bin/bash

set -euo pipefail

# Update GO_VERSION and GO_SHA256 together when bumping.
# SHA256 values: https://go.dev/dl/?mode=json
GO_VERSION="1.26.0"
GO_SHA256="aac1b08a0fb0c4e0a7c1555beb7b59180b05dfc5a3d62e40e9de90cd42f88235"
GO_ARCHIVE="go${GO_VERSION}.linux-amd64.tar.gz"

_tmpfile=$(mktemp --suffix=-"$GO_ARCHIVE")
curl -fsSL -o "$_tmpfile" "https://go.dev/dl/$GO_ARCHIVE"

actual=$(sha256sum "$_tmpfile" | cut -d' ' -f1)
if [[ "$actual" != "$GO_SHA256" ]]; then
    echo "[!] Go tarball checksum mismatch"
    echo "[!]   expected: $GO_SHA256"
    echo "[!]   actual:   $actual"
    rm -f "$_tmpfile"
    exit 1
fi
echo "[*] Go tarball checksum OK"

sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "$_tmpfile"
rm -f "$_tmpfile"

sudo ln -sf /usr/local/go/bin/go /usr/local/bin/go

go version
