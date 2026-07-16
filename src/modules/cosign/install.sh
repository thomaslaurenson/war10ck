#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

LATEST_TAG=$(w_github_latest_tag "sigstore/cosign")

readonly ARCHIVE="cosign_${LATEST_TAG}_amd64.deb"
readonly URL_DOWNLOAD="https://github.com/sigstore/cosign/releases/download/v${LATEST_TAG}/${ARCHIVE}"
readonly URL_CHECKSUMS="https://github.com/sigstore/cosign/releases/download/v${LATEST_TAG}/cosign_checksums.txt"

_tmpdeb=$(mktemp --suffix=-"${ARCHIVE}")
w_download "${URL_DOWNLOAD}" "${_tmpdeb}"

if ! w_github_checksums_verify "${_tmpdeb}" "${ARCHIVE}" "${URL_CHECKSUMS}"; then
  rm -f "${_tmpdeb}"
  exit 1
fi

w_q sudo dpkg -i "${_tmpdeb}"
rm -f "${_tmpdeb}"

w_log_info "cosign module installed."
