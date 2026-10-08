#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Aseprite sells its Linux binaries and publishes only source on GitHub. The
# EULA allows compiling that source for personal use, so this builds the
# release locally rather than needing a Steam or store account.
#
# None of the three downloads below has a checksums file beside it, so each
# SHA256 is pinned here and that pin is what verifies it. To bump one, change
# its version, re-download the archive and replace the hash with the output of
# sha256sum.
readonly ASEPRITE_VERSION="1.3.18.6"
readonly ASEPRITE_SHA256="fa9dd07a0c2a5ec91a4166333296bbb9e5c237933b59875d0cfee849d2358306"
readonly ASEPRITE_RELEASES="https://github.com/aseprite/aseprite/releases/download"
readonly ASEPRITE_ARCHIVE="Aseprite-v${ASEPRITE_VERSION}-Source.zip"
readonly ASEPRITE_URL="${ASEPRITE_RELEASES}/v${ASEPRITE_VERSION}/${ASEPRITE_ARCHIVE}"
readonly ASEPRITE_DIR="/opt/aseprite"

# Each Aseprite release names the one Skia build it links against in
# laf/misc/skia-tag.txt, and aseprite/skia publishes newer tags than that, so
# "latest" is the wrong choice here. The build checks the two agree before
# compiling, so an Aseprite bump that moves Skia fails at once with both tags
# named rather than deep in the link step.
readonly SKIA_TAG="m124-08a5439a6b"
readonly SKIA_SHA256="a327e89b244f24cecaa34eb37544bae00d447b96c583d26ed29d6a3ad2e8a8b8"
readonly SKIA_RELEASE="https://github.com/aseprite/skia/releases/download/${SKIA_TAG}"
readonly SKIA_URL="${SKIA_RELEASE}/Skia-Linux-Release-x64.zip"

# diivi/aseprite-mcp tags no releases, so a commit is the only thing to pin.
# Its uv.lock pins every Python dependency by hash, and the sync below uses
# --locked so a lock that disagrees with pyproject.toml fails the install.
readonly ASEPRITE_MCP_COMMIT="90d1696a7e41edff89bbd0823ae6a5f86c114bcc"
readonly ASEPRITE_MCP_SHA256="c1c9549991923d6a05b726996d4a9012de01f4f6514480a38108502e08271970"
readonly ASEPRITE_MCP_REPO="https://github.com/diivi/aseprite-mcp"
readonly ASEPRITE_MCP_URL="${ASEPRITE_MCP_REPO}/archive/${ASEPRITE_MCP_COMMIT}.tar.gz"
readonly ASEPRITE_MCP_DIR="${HOME}/.local/share/aseprite-mcp"

# Every download and the build tree live under one directory, removed by the
# EXIT trap, so a failed download or build cannot leave a source tree in /tmp.
_workdir=$(mktemp -d --suffix=-aseprite)
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

# Return 0 when the Aseprite in ASEPRITE_DIR is the pinned version.
#
# The build takes several minutes, so a re-run of the module only rebuilds when
# the pin has moved. Every build from the source zip reports a -dev suffix, a
# version hardcoded in src/ver/CMakeLists.txt, so the bare version never
# matches.
#
# Globals:
#   ASEPRITE_DIR, ASEPRITE_VERSION - read only
_aseprite_is_current() {
  local reported
  [[ -x "${ASEPRITE_DIR}/aseprite" ]] || return 1
  reported=$("${ASEPRITE_DIR}/aseprite" --version 2>/dev/null) || return 1
  [[ "${reported}" == "Aseprite ${ASEPRITE_VERSION}-dev" ]]
}

# Build Aseprite from the pinned source release and install it to ASEPRITE_DIR.
#
# Globals:
#   ASEPRITE_*, SKIA_* - read only
#   _workdir           - scratch directory for the downloads and build tree
_build_aseprite() {
  local src="${_workdir}/src"
  local skia="${_workdir}/skia"
  local build="${_workdir}/build"
  local tag

  _fetch_verified "${ASEPRITE_URL}" "${ASEPRITE_SHA256}" "${_workdir}/aseprite-src.zip"
  _fetch_verified "${SKIA_URL}" "${SKIA_SHA256}" "${_workdir}/skia.zip"

  # Both archives unpack straight into the target, with no top-level directory.
  w_q unzip -q "${_workdir}/aseprite-src.zip" -d "${src}"
  w_q unzip -q "${_workdir}/skia.zip" -d "${skia}"

  tag=$(<"${src}/laf/misc/skia-tag.txt")
  if [[ "${tag}" != "${SKIA_TAG}" ]]; then
    w_log_error "Aseprite ${ASEPRITE_VERSION} expects Skia ${tag}, but SKIA_TAG is ${SKIA_TAG}"
    return 1
  fi

  # The prebuilt Skia is compiled against libstdc++, so clang has to link the
  # same library rather than its own libc++, as upstream INSTALL.md describes.
  w_log_info "Building Aseprite ${ASEPRITE_VERSION}. This takes several minutes."
  w_q cmake \
    -S "${src}" \
    -B "${build}" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_CXX_FLAGS:STRING=-stdlib=libstdc++ \
    -DCMAKE_EXE_LINKER_FLAGS:STRING=-stdlib=libstdc++ \
    -DLAF_BACKEND=skia \
    -DSKIA_DIR="${skia}" \
    -DSKIA_LIBRARY_DIR="${skia}/out/Release-x64" \
    -DSKIA_LIBRARY="${skia}/out/Release-x64/libskia.a"
  w_q cmake --build "${build}" --target aseprite

  # Copied from bin/ rather than run through cmake --install, which would also
  # install the headers and static libraries of every bundled third-party
  # library. The binary finds its data directory beside itself.
  w_sudo_remove_dir "${ASEPRITE_DIR}"
  w_sudo_mkdir "${ASEPRITE_DIR}"
  sudo cp "${build}/bin/aseprite" "${ASEPRITE_DIR}/aseprite"
  sudo cp -r "${build}/bin/data" "${ASEPRITE_DIR}/data"
  w_sudo_symlink "${ASEPRITE_DIR}/aseprite" /usr/local/bin/aseprite
}

# Install the aseprite MCP server at the pinned commit with its locked
# dependencies. The directory is replaced outright, which also rebuilds the
# virtual environment uv keeps inside it.
#
# Arguments:
#   $1 - path to the uv binary
# Globals:
#   ASEPRITE_MCP_* - read only
#   _workdir       - scratch directory for the download
_install_mcp() {
  local uv=$1
  local archive="${_workdir}/aseprite-mcp.tar.gz"

  _fetch_verified "${ASEPRITE_MCP_URL}" "${ASEPRITE_MCP_SHA256}" "${archive}"

  w_remove_dir "${ASEPRITE_MCP_DIR}"
  mkdir -p "${ASEPRITE_MCP_DIR}"
  tar -xzf "${archive}" -C "${ASEPRITE_MCP_DIR}" --strip-components=1

  w_q "${uv}" --directory "${ASEPRITE_MCP_DIR}" sync --locked --no-dev
}

main() {
  # aseprite/skia publishes no 64-bit Linux build other than x64.
  if [[ "$(uname -m)" != "x86_64" ]]; then
    w_log_error "Unsupported architecture: $(uname -m)"
    exit 1
  fi

  # Checked before the build rather than after it, so a missing uv costs
  # nothing.
  local uv
  if ! uv=$(command -v uv); then
    w_log_error "uv not found. Install it with: war10ck install uv"
    exit 1
  fi

  # Upstream INSTALL.md's Debian list. clang is the unversioned package on
  # purpose: the cpp module's clang-18 pin is about formatting output, and has
  # no bearing on which compiler builds Aseprite.
  w_apt_install \
    g++ \
    clang \
    cmake \
    ninja-build \
    unzip \
    libx11-dev \
    libxcursor-dev \
    libxi-dev \
    libxrandr-dev \
    libgl1-mesa-dev \
    libfontconfig1-dev

  if _aseprite_is_current; then
    w_log_info "Aseprite ${ASEPRITE_VERSION} already installed. Skipping build."
  else
    _build_aseprite
  fi

  _install_mcp "${uv}"

  w_log_info "aseprite module installed (${ASEPRITE_VERSION})."
}

main "$@"
