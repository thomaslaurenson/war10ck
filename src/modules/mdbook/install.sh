#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# mdBook publishes no checksums file with its releases, so the version is
# pinned and its SHA256 recorded here - that pin is the only thing standing
# between this and installing whatever the URL happens to serve. Tracking
# "latest" is incompatible with pinning a hash, which is why the version is
# fixed rather than resolved at runtime.
#
# To bump: change the version, re-download the archive, and replace the hash
# with the output of sha256sum.
readonly MDBOOK_VERSION="0.5.4"
readonly MDBOOK_SHA256="3f28de05dafca9d0f2eab99c662116b0e37b89b1d96a08f8f430b9eeae958cd7"

readonly MDBOOK_ARCHIVE="mdbook-v${MDBOOK_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
readonly MDBOOK_URL="https://github.com/rust-lang/mdBook/releases/download/v${MDBOOK_VERSION}/${MDBOOK_ARCHIVE}"

_tmparchive=$(mktemp --suffix="-${MDBOOK_ARCHIVE}")
w_download "${MDBOOK_URL}" "${_tmparchive}"

if ! w_verify_sha256 "${_tmparchive}" "${MDBOOK_SHA256}"; then
  rm -f "${_tmparchive}"
  exit 1
fi

_tmpdir=$(mktemp -d --suffix=-mdbook)
w_q tar -xzf "${_tmparchive}" -C "${_tmpdir}"
rm -f "${_tmparchive}"

sudo install -m 0755 "${_tmpdir}/mdbook" /usr/local/bin/mdbook
rm -rf "${_tmpdir}"

w_log_info "mdbook ${MDBOOK_VERSION} installed."
