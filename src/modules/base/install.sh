#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# The tools every other module, and every project built on this machine, assumes
# are already there. Today they arrive as dependencies of whichever module
# happens to be installed first - unzip with fnm, gnupg with vault, curl with
# docker - which leaves a server that skips those modules quietly different from
# a desktop that does not. Naming them here makes the baseline deliberate; the
# modules that need them keep naming them too, so each stays installable alone.
#
# make is listed beside build-essential, which already depends on it, for the
# same reason. Every project in this toolchain is driven through its Makefile,
# so make should not be a package that arrives by accident.
w_apt_install \
  build-essential \
  make \
  curl \
  gnupg \
  jq \
  pass \
  unzip \
  vim

w_log_info "base module installed."
