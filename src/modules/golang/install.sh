#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Update GO_VERSION and GO_SHA256 together when bumping.
# SHA256 values: https://go.dev/dl/?mode=json
GO_VERSION="1.26.4"
GO_SHA256="1153d3d50e0ac764b447adfe05c2bcf08e889d42a02e0fe0259bd47f6733ad7f"
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

# Update GORELEASER_VERSION and GORELEASER_SHA256 together when bumping.
# SHA256 values: https://github.com/goreleaser/goreleaser/releases
GORELEASER_VERSION="2.16.0"
GORELEASER_SHA256="eaae05b5eba07533bd0f06846b68c808399504784df00c62eb219541fc04e5e2"
GORELEASER_ARCHIVE="goreleaser_Linux_x86_64.tar.gz"

_tmpfile=$(mktemp --suffix=-"$GORELEASER_ARCHIVE")
curl -fsSL -o "$_tmpfile" "https://github.com/goreleaser/goreleaser/releases/download/v${GORELEASER_VERSION}/$GORELEASER_ARCHIVE"

if ! w_verify_sha256 "$_tmpfile" "$GORELEASER_SHA256"; then
    rm -f "$_tmpfile"
    exit 1
fi

_tmpdir=$(mktemp -d)
tar -C "$_tmpdir" -xzf "$_tmpfile" goreleaser
sudo mv "$_tmpdir/goreleaser" /usr/local/bin/goreleaser
sudo chmod +x /usr/local/bin/goreleaser
rm -f "$_tmpfile"
rmdir "$_tmpdir"

w_log_info "golang module installed."
