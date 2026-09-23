#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Nothing is removed. Everything base installs is either a dependency of another
# module (gnupg for vault, unzip for fnm, curl for docker) or of the system
# itself, so removing a package here would either be undone by the next module
# installed or take a working toolchain out from under the machine. war10ck
# fetches with curl, so this module can uninstall its own installer.
#
# The module is a guarantee that these packages are present, not a claim to own
# them, and the uninstall says so rather than pretending there is nothing here.
w_log_info "base module uninstalled (packages left in place)."
