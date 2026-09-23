#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Clang is pinned to one major version across every C++ project: formatting
# output and check behaviour differ between majors, so a tree formatted with one
# and checked with another fails check_format on lines nobody touched. Project
# Makefiles resolve clang-format-18 before falling back to the bare name, and CI
# installs the same number, so this has to agree with both.
#
# Debian 13 defaults to clang 19 and carries the versioned 18 packages beside
# it, so the pin costs nothing: no apt.llvm.org key or source is needed.
readonly CLANG_VERSION="18"

# The compiler itself, not only the two tools. check_lint configures a
# clang-pinned build directory of its own so clang-tidy can resolve libstdc++
# headers; without clang present it reads a GCC-configured compile_commands.json
# and emits diagnostics from a broken AST that look like real findings.
#
# cmake from trixie is 3.31, comfortably past the 3.21 minimum every project
# declares. g++ arrives with build-essential in the base module and is named
# again here, so a machine that installs cpp on its own still has the GCC half
# of the two-compiler build CI runs.
w_apt_install \
  cmake \
  g++ \
  "clang-${CLANG_VERSION}" \
  "clang-format-${CLANG_VERSION}" \
  "clang-tidy-${CLANG_VERSION}"

w_log_info "cpp module installed."
