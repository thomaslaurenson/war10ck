#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# On Linux emsdk bundles no Python, so both emsdk and emcc run on the system
# python3. It fetches its archives with Python's urllib, which verifies TLS
# against the system CA store, and unpacks them by shelling out to tar, which
# needs xz for the .tar.xz releases. base names none of these.
w_apt_install \
  ca-certificates \
  git \
  python3 \
  xz-utils

# emsdk tags its repository with every SDK release, so the checkout is pinned
# to the same tag as the SDK it installs. Keep this in step with the version
# the game CI builds with.
readonly EMSDK_VERSION="4.0.10"
readonly EMSDK_REPO="https://github.com/emscripten-core/emsdk.git"
readonly EMSDK_DIR="${HOME}/.local/share/emsdk"

# An existing checkout is moved to the pinned tag rather than reused as it is.
# A checkout taken at an older tag has a release list that predates a bumped
# EMSDK_VERSION, and emsdk install would then fail with the SDK not found.
if [[ -d "${EMSDK_DIR}/.git" ]]; then
  w_log_info "Moving emsdk checkout to ${EMSDK_VERSION}"
  w_q git -C "${EMSDK_DIR}" fetch --depth 1 "${EMSDK_REPO}" \
    "refs/tags/${EMSDK_VERSION}:refs/tags/${EMSDK_VERSION}"
  w_q git -C "${EMSDK_DIR}" checkout --detach "${EMSDK_VERSION}"
elif [[ -e "${EMSDK_DIR}" ]]; then
  w_log_error "${EMSDK_DIR} exists but is not a git checkout. Remove it and re-run"
  exit 1
else
  w_log_info "Cloning emsdk ${EMSDK_VERSION}"
  w_q git clone --depth 1 --branch "${EMSDK_VERSION}" "${EMSDK_REPO}" "${EMSDK_DIR}"
fi

# install skips anything already present, so a re-run costs little. activate
# writes ${EMSDK_DIR}/.emscripten, the config emcc reads its tool paths from,
# and changes no shell startup file.
w_log_info "Installing Emscripten SDK ${EMSDK_VERSION}. This takes a few minutes."
w_q "${EMSDK_DIR}/emsdk" install "${EMSDK_VERSION}"
w_q "${EMSDK_DIR}/emsdk" activate "${EMSDK_VERSION}"

w_log_info "emsdk module installed (${EMSDK_VERSION})."
