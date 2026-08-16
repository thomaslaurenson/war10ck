#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# mdbook-mermaid is an mdBook preprocessor - useless without mdbook itself.
if ! w_is_installed mdbook; then
    w_log_info "mdbook not found. Install it with: war10ck install mdbook"
fi

# mdbook-mermaid publishes no checksums file with its releases, so the version
# is pinned and its SHA256 recorded here - that pin is the only thing standing
# between this and installing whatever the URL happens to serve. Tracking
# "latest" is incompatible with pinning a hash, which is why the version is
# fixed rather than resolved at runtime.
#
# To bump: change the version, re-download the archive, and replace the hash
# with the output of sha256sum.
readonly MERMAID_VERSION="0.17.1"
readonly MERMAID_SHA256="9afcfa5b8463afe606d48595a7ae338564302903e626ea5b6edb8007d29393a5"

readonly MERMAID_ARCHIVE="mdbook-mermaid-v${MERMAID_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
readonly MERMAID_URL="https://github.com/badboy/mdbook-mermaid/releases/download/v${MERMAID_VERSION}/${MERMAID_ARCHIVE}"

_tmparchive=$(mktemp --suffix="-${MERMAID_ARCHIVE}")
w_download "${MERMAID_URL}" "${_tmparchive}"

if ! w_verify_sha256 "${_tmparchive}" "${MERMAID_SHA256}"; then
  rm -f "${_tmparchive}"
  exit 1
fi

_tmpdir=$(mktemp -d --suffix=-mdbook-mermaid)
w_q tar -xzf "${_tmparchive}" -C "${_tmpdir}"
rm -f "${_tmparchive}"

sudo install -m 0755 "${_tmpdir}/mdbook-mermaid" /usr/local/bin/mdbook-mermaid
rm -rf "${_tmpdir}"

w_log_info "mdbook-mermaid ${MERMAID_VERSION} installed."
w_log_info "Enable it in a book with: mdbook-mermaid install <book-dir>"
