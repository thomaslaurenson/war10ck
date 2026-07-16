#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Update GO_VERSION and GO_SHA256 together when bumping.
# SHA256 values: https://go.dev/dl/?mode=json
readonly GO_VERSION="1.26.4"
readonly GO_SHA256="1153d3d50e0ac764b447adfe05c2bcf08e889d42a02e0fe0259bd47f6733ad7f"
readonly GO_ARCHIVE="go${GO_VERSION}.linux-amd64.tar.gz"

_tmpfile=$(mktemp --suffix=-"${GO_ARCHIVE}")
w_download "https://go.dev/dl/${GO_ARCHIVE}" "${_tmpfile}"

if ! w_verify_sha256 "${_tmpfile}" "${GO_SHA256}"; then
  rm -f "${_tmpfile}"
  exit 1
fi

w_sudo_remove_dir /usr/local/go
w_q sudo tar -C /usr/local -xzf "${_tmpfile}"
rm -f "${_tmpfile}"

w_sudo_symlink /usr/local/go/bin/go /usr/local/bin/go
w_sudo_symlink /usr/local/go/bin/gofmt /usr/local/bin/gofmt

# Update GORELEASER_VERSION and GORELEASER_SHA256 together when bumping.
# SHA256 values: https://github.com/goreleaser/goreleaser/releases
readonly GORELEASER_VERSION="2.16.0"
readonly GORELEASER_SHA256="eaae05b5eba07533bd0f06846b68c808399504784df00c62eb219541fc04e5e2"
readonly GORELEASER_ARCHIVE="goreleaser_Linux_x86_64.tar.gz"

_tmpfile=$(mktemp --suffix=-"${GORELEASER_ARCHIVE}")
w_download "https://github.com/goreleaser/goreleaser/releases/download/v${GORELEASER_VERSION}/${GORELEASER_ARCHIVE}" \
  "${_tmpfile}"

if ! w_verify_sha256 "${_tmpfile}" "${GORELEASER_SHA256}"; then
  rm -f "${_tmpfile}"
  exit 1
fi

_tmpdir=$(mktemp -d)
tar -C "${_tmpdir}" -xzf "${_tmpfile}" goreleaser
sudo mv "${_tmpdir}/goreleaser" /usr/local/bin/goreleaser
w_sudo_make_executable /usr/local/bin/goreleaser
rm -f "${_tmpfile}"
rmdir "${_tmpdir}"

w_log_info "golang module installed."
