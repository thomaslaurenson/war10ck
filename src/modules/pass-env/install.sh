#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# pass-env is a pass extension, so pass and gnupg are hard requirements.
# fzf is optional upstream, but it is what makes interactive entry selection
# work, so it is installed here rather than left to be discovered later.
w_apt_install pass gnupg fzf

PASS_ENV_URL="https://github.com/thomaslaurenson/pass-env/releases/latest/download"

_tmpinstaller=$(mktemp --suffix=-pass-env-install.sh)
w_download "$PASS_ENV_URL/install.sh" "$_tmpinstaller"

# The published checksums.txt covers install.sh itself, which is the flow the
# pass-env README documents for inspecting a release before running it.
if ! w_github_checksums_verify "$_tmpinstaller" "install.sh" "$PASS_ENV_URL/checksums.txt"; then
    rm -f "$_tmpinstaller"
    exit 1
fi

# Run as the invoking user rather than under sudo. The installer escalates
# internally for the system paths it needs (maybe_install/maybe_mkdir), and
# leaving $HOME alone is what lets it hook the right ~/.bashrc instead of
# root's. --yes makes it non-interactive.
#
# Shell integration is deliberately left to the installer: --no-init would skip
# writing pass-env-init.sh as well as the RC block, so there would be nothing
# for war10ck to source. Its RC edits are sentinel-guarded and idempotent, and
# its own uninstaller is what knows how to reverse them.
bash "$_tmpinstaller" --yes
rm -f "$_tmpinstaller"

w_log_info "pass-env module installed."
w_log_info "Open a new shell, then try: passenv --help"
