#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Update GO_VERSION and GO_SHA256 together when bumping.
# SHA256 values: https://go.dev/dl/?mode=json
GO_VERSION="1.26.2"
GO_SHA256="990e6b4bbba816dc3ee129eaeaf4b42f17c2800b88a2166c265ac1a200262282"
GO_ARCHIVE="go${GO_VERSION}.linux-amd64.tar.gz"

_tmpfile=$(mktemp --suffix=-"$GO_ARCHIVE")
curl -fsSL -o "$_tmpfile" "https://go.dev/dl/$GO_ARCHIVE"

if ! w_verify_sha256 "$_tmpfile" "$GO_SHA256"; then
    rm -f "$_tmpfile"
    exit 1
fi

w_q sudo rm -rf /usr/local/go
w_q sudo tar -C /usr/local -xzf "$_tmpfile"
rm -f "$_tmpfile"

sudo ln -sf /usr/local/go/bin/go /usr/local/bin/go
sudo ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

w_log_info "golang module installed."
