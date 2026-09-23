#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Temp paths are registered here and removed by the EXIT trap, so a failed
# download or a checksum mismatch cannot leave a half-fetched binary behind.
_tmppaths=()
_cleanup() {
  [[ ${#_tmppaths[@]} -gt 0 ]] && rm -rf "${_tmppaths[@]}"
  return 0
}
trap _cleanup EXIT

# `filen mount` hands the mount to a managed Rclone, which mounts over FUSE,
# so libfuse3 and fusermount3 are hard requirements. Without them the CLI
# installs fine and then refuses to mount.
w_apt_install fuse3

# The upstream install method, kept here so the two can be compared:
#
#   curl -sL https://raw.githubusercontent.com/FilenCloudDienste/filen-rs/refs/heads/main/filen-cli/install.sh | bash
#
# It is not what this module runs. It resolves "latest" at fetch time, which
# is unpinned and unverifiable; it drops the binary in ~/.filen-cli/bin and
# appends a PATH line to every shell profile it finds, which war10ck manages
# itself; and no lifecycle script may call curl directly.
#
# Filen publishes no checksums file with its releases, so the version is pinned
# and its SHA256 recorded here - that pin is the only thing standing between
# this and installing whatever the URL happens to serve.
#
# To bump: change the version, re-download the binary, and replace the hash
# with the output of sha256sum.
readonly FILEN_VERSION="0.2.7"
readonly FILEN_SHA256="d05c3a4a7585cbbfe936da7a479738982928df49576bd2374c8b608b4d889189"

# The Rust CLI, which replaces the sunsetted Node one. Releases live in a
# separate repository from the source, and the tags carry no leading "v".
readonly FILEN_BINARY="filen-cli-${FILEN_VERSION}-x86_64-unknown-linux-gnu"
readonly FILEN_URL="https://github.com/FilenCloudDienste/filen-cli-releases/releases/download/${FILEN_VERSION}/${FILEN_BINARY}"

_tmpfile=$(mktemp --suffix="-${FILEN_BINARY}")
_tmppaths+=("${_tmpfile}")
w_download "${FILEN_URL}" "${_tmpfile}"

if ! w_verify_sha256 "${_tmpfile}" "${FILEN_SHA256}"; then
  exit 1
fi

sudo install -m 0755 "${_tmpfile}" /usr/local/bin/filen

w_log_info "filen ${FILEN_VERSION} installed."
w_log_info "Authenticate with FILEN_CLI_EMAIL and FILEN_CLI_PASSWORD in the environment."
w_log_info "Mount with: pass env run env/filen.env -- filen mount <dir> (the CLI will not create it)"
