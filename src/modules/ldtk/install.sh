#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# LDtk publishes no checksums file beside its releases, so the SHA256 of the
# Linux zip is pinned here and that pin is what verifies it. To bump, change
# the version, re-download the zip and replace the hash with the output of
# sha256sum. The zip holds a single AppImage, which upstream names "installer"
# although it is the app itself.
readonly LDTK_VERSION="1.5.3"
readonly LDTK_SHA256="8bb1c870ab35d2cadfbf08a119d3049e7986a2a80558d2610babc67fcd502566"
readonly LDTK_RELEASES="https://github.com/deepnight/ldtk/releases/download"
readonly LDTK_URL="${LDTK_RELEASES}/v${LDTK_VERSION}/ubuntu-distribution.zip"
readonly LDTK_APPIMAGE="LDtk ${LDTK_VERSION} installer.AppImage"
readonly LDTK_DIR="/opt/ldtk"

# gazure/ldtk-mcp tags no releases and is not on crates.io, so a commit is the
# only thing to pin. Its Cargo.lock pins every crate by checksum, and the build
# below uses --locked so a lock that disagrees with Cargo.toml fails the install.
readonly LDTK_MCP_COMMIT="92ec14aba1f5354316dcb8ce618d1a63c0189411"
readonly LDTK_MCP_SHA256="df5b38644a179e8213e1f2924298c7c0ea031af565b71adf8efc347084872b7f"
readonly LDTK_MCP_REPO="https://github.com/gazure/ldtk-mcp"
readonly LDTK_MCP_URL="${LDTK_MCP_REPO}/archive/${LDTK_MCP_COMMIT}.tar.gz"
readonly LDTK_MCP_BIN="/usr/local/bin/ldtk-mcp"

# Every download and the build tree live under one directory, removed by the
# EXIT trap, so a failed download or build cannot leave anything in /tmp.
_workdir=$(mktemp -d --suffix=-ldtk)
_cleanup() {
  rm -rf "${_workdir}"
}
trap _cleanup EXIT

# Download a file and verify it against a pinned SHA256.
#
# Arguments:
#   $1 - URL to download
#   $2 - expected SHA256
#   $3 - destination path
# Returns:
#   1 when the checksum does not match
_fetch_verified() {
  w_download "$1" "$3"
  w_verify_sha256 "$3" "$2"
}

# Install LDtk from the pinned release into LDTK_DIR.
#
# The AppImage is unpacked rather than installed as-is, because run as an
# AppImage it needs FUSE 2, which Debian no longer installs by default.
#
# Globals:
#   LDTK_* - read only
#   _workdir - scratch directory for the download and the unpacked tree
_install_ldtk() {
  local zip="${_workdir}/ldtk.zip"
  local appimage="${_workdir}/ldtk.AppImage"

  _fetch_verified "${LDTK_URL}" "${LDTK_SHA256}" "${zip}"
  unzip -p "${zip}" "${LDTK_APPIMAGE}" > "${appimage}"
  chmod +x "${appimage}"

  # --appimage-extract takes no destination: it always writes squashfs-root
  # into the current directory.
  (cd "${_workdir}" && w_q "${appimage}" --appimage-extract)

  # The AppImage runtime unpacks every directory as 0700 and cp keeps those
  # modes, so without this only root could start the app.
  chmod -R u=rwX,go=rX "${_workdir}/squashfs-root"

  w_sudo_remove_dir "${LDTK_DIR}"
  sudo cp -r "${_workdir}/squashfs-root" "${LDTK_DIR}"
  w_sudo_symlink "${LDTK_DIR}/ldtk" /usr/local/bin/ldtk
}

# Build the LDtk MCP server at the pinned commit and install it to
# LDTK_MCP_BIN.
#
# CARGO_HOME points into the work directory, so the crate downloads and the
# registry index go with it rather than piling up under ~/.cargo.
#
# Globals:
#   LDTK_MCP_* - read only
#   _workdir   - scratch directory for the download and the build tree
_install_mcp() {
  local archive="${_workdir}/ldtk-mcp.tar.gz"
  local src="${_workdir}/ldtk-mcp"

  _fetch_verified "${LDTK_MCP_URL}" "${LDTK_MCP_SHA256}" "${archive}"
  mkdir -p "${src}"
  tar -xzf "${archive}" -C "${src}" --strip-components=1

  # w_q hides cargo's output, so without this a failed build ends the install
  # with no message at all.
  w_log_info "Building ldtk-mcp. This takes a few minutes."
  if ! w_q env CARGO_HOME="${_workdir}/cargo" \
    cargo build --release --locked --manifest-path "${src}/Cargo.toml"; then
    w_log_error "ldtk-mcp build failed. Re-run with --debug to see cargo's output."
    return 1
  fi
  sudo install -m 0755 "${src}/target/release/ldtk-mcp" "${LDTK_MCP_BIN}"
}

main() {
  # LDtk publishes no Linux build other than x64.
  if [[ "$(uname -m)" != "x86_64" ]]; then
    w_log_error "Unsupported architecture: $(uname -m)"
    exit 1
  fi

  # cargo-web rather than cargo: Debian's plain cargo is Rust 1.85, and the
  # MCP server's lockfile needs 1.88 or newer. cargo-web is the newer toolchain
  # Debian maintains for building browsers. It provides cargo, and conflicts
  # with the plain cargo package and with rustup, so apt replaces either.
  w_apt_install unzip cargo-web

  _install_ldtk
  _install_mcp

  w_log_info "ldtk module installed (${LDTK_VERSION})."
}

main "$@"
