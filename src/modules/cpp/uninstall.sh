#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

readonly CLANG_VERSION="18"

# g++ is left in place: it belongs to build-essential in the base module, and
# taking it out would strip the system compiler from a machine that still has
# other things to build.
w_apt_remove \
  cmake \
  "clang-${CLANG_VERSION}" \
  "clang-format-${CLANG_VERSION}" \
  "clang-tidy-${CLANG_VERSION}"

w_log_info "cpp module uninstalled."
