#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

readonly CLAUDE_DESKTOP_URL="https://downloads.claude.ai/claude-desktop"
readonly CLAUDE_DESKTOP_KEY_URL="${CLAUDE_DESKTOP_URL}/key.asc"
readonly CLAUDE_DESKTOP_REPO="${CLAUDE_DESKTOP_URL}/apt/stable"

# Published in Anthropic's install instructions rather than beside the key. The
# key is served from the same host as the packages it signs, so a download
# that merely succeeds proves nothing a compromised host could not also serve.
readonly CLAUDE_DESKTOP_KEY_FPR="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"

# The repository carries amd64 and arm64 only. Anywhere else apt would report
# the package as missing without saying why.
_arch=$(dpkg --print-architecture)
case "${_arch}" in
  amd64|arm64) ;;
  *)
    w_log_error "Unsupported architecture: ${_arch}"
    exit 1
    ;;
esac

w_apt_install curl gpg
w_apt_add_key "claude-desktop" "${CLAUDE_DESKTOP_KEY_URL}" \
  "${CLAUDE_DESKTOP_KEY_FPR}"

# The package registers this repository itself on install, unless a source
# for it already exists, and leaves a source it did not write in place. The
# entry below is therefore the one apt uses, and uninstall has to remove it.
_entry="deb [arch=amd64,arm64 signed-by=/etc/apt/keyrings/claude-desktop.gpg]"
_entry+=" ${CLAUDE_DESKTOP_REPO} stable main"
w_apt_add_source "claude-desktop" "${_entry}"

# Recommends stay on: they bring QEMU, OVMF and virtiofsd, which Cowork runs
# its VM on.
w_apt_install claude-desktop

w_log_info "claude-desktop module installed."
