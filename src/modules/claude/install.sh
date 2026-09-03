#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Temp paths are registered here and removed by the EXIT trap, so a failed
# download cannot leave a half-fetched file behind.
_tmppaths=()
_cleanup() {
  [[ ${#_tmppaths[@]} -gt 0 ]] && rm -rf "${_tmppaths[@]}"
  return 0
}
trap _cleanup EXIT

# Optional as far as the installer is concerned, and worth having: with zstd
# present the binary arrives compressed at about 76MB rather than the 207MB a
# plain download costs. Without it the installer falls back silently.
w_apt_install zstd

readonly CLAUDE_INSTALLER_URL="https://claude.ai/install.sh"
readonly CLAUDE_RELEASES_URL="https://downloads.claude.ai/claude-code-releases"
readonly CLAUDE_LAUNCHER="${HOME}/.local/bin/claude"

# A channel rather than a version. Claude Code updates itself into
# ~/.local/share/claude/versions, so a pinned version would govern the first
# install and be stale by the second run.
readonly CLAUDE_CHANNEL="latest"

# Anthropic publishes the installer at one rolling URL: there is no versioned
# copy of it and no checksums file alongside it, so a hash pinned here would
# fail closed on every routine edit upstream while proving nothing the TLS
# connection has not already established. What gets verified instead is the
# artefact that matters, below: the binary the installer leaves on disk, against
# the SHA256 Anthropic publishes for that exact version.
_tmpinstaller=$(mktemp --suffix=-claude-install.sh)
_tmppaths+=("${_tmpinstaller}")
w_download "${CLAUDE_INSTALLER_URL}" "${_tmpinstaller}"

# Run from a file rather than piped into bash: the installer executes the binary
# it fetches, and a pipe would hand that process this script's stdin.
w_q bash "${_tmpinstaller}" "${CLAUDE_CHANNEL}"

if [[ ! -e "${CLAUDE_LAUNCHER}" ]]; then
  w_log_error "Installer finished but ${CLAUDE_LAUNCHER} is missing"
  exit 1
fi

# The launcher is a symlink to the versioned binary, so it names the installed
# version without running a 200MB executable to ask it.
_binary=$(readlink -f "${CLAUDE_LAUNCHER}")
_version=$(basename "${_binary}")
if [[ ! "${_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  w_log_error "Cannot read an installed version from ${CLAUDE_LAUNCHER}"
  exit 1
fi

# Debian and Ubuntu are glibc, which is the whole of what war10ck targets, so
# the musl builds the manifest also carries are not considered here.
case "$(uname -m)" in
  x86_64) _platform="linux-x64" ;;
  aarch64) _platform="linux-arm64" ;;
  *)
    w_log_error "Unsupported architecture: $(uname -m)"
    exit 1
    ;;
esac

_tmpmanifest=$(mktemp --suffix=-claude-manifest.json)
_tmppaths+=("${_tmpmanifest}")
w_download "${CLAUDE_RELEASES_URL}/${_version}/manifest.json" "${_tmpmanifest}"

# Flattened before matching rather than read line by line: the manifest is
# pretty-printed today and nothing upstream promises it stays that way. The
# [^{}] holds the match inside the platform's own object, since every platform
# is a block of its own under the same keys.
_manifest=$(tr -d '\n\r\t' < "${_tmpmanifest}")
_pattern="\"${_platform}\"[[:space:]]*:[[:space:]]*\{[^{}]*"
_pattern+="\"checksum\"[[:space:]]*:[[:space:]]*\"([a-f0-9]{64})\""
if [[ ! "${_manifest}" =~ ${_pattern} ]]; then
  w_log_error "No ${_platform} checksum published for claude ${_version}"
  exit 1
fi
_checksum="${BASH_REMATCH[1]}"

# A mismatch fails the module rather than deleting the binary: war10ck cannot
# tell a tampered download from an installation that was already on the machine,
# and removing the second takes a working CLI with it. Exiting non-zero is
# enough to keep the module out of the registry.
if ! w_verify_sha256 "${_binary}" "${_checksum}"; then
  exit 1
fi

w_log_info "claude module installed (${_version})."
