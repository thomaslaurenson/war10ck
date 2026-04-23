#!/bin/bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# In normal mode all noisy commands are silenced; debug mode streams full output.
_q() { if [[ "${WAR10CK_DEBUG:-0}" == "1" ]]; then "$@"; else "$@" >/dev/null 2>&1; fi; }

# Update GO_VERSION and GO_SHA256 together when bumping.
# SHA256 values: https://go.dev/dl/?mode=json
GO_VERSION="1.26.2"
GO_SHA256="990e6b4bbba816dc3ee129eaeaf4b42f17c2800b88a2166c265ac1a200262282"
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

_q sudo rm -rf /usr/local/go
_q sudo tar -C /usr/local -xzf "$_tmpfile"
rm -f "$_tmpfile"

sudo ln -sf /usr/local/go/bin/go /usr/local/bin/go
sudo ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
