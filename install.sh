#!/usr/bin/env bash
set -euo pipefail

die() { printf '%s: %s\n' "${0##*/}" "$*" >&2; exit 1; }

URL="https://war10ck.thomaslaurenson.com"

if command -v curl &>/dev/null; then
  FETCH_CMD="curl -fsSL -o"
elif command -v wget &>/dev/null; then
  FETCH_CMD="wget -q -O"
else
  die "no fetch command found (need curl or wget)"
fi

tmp_binary=$(mktemp --suffix="-war10ck")
tmp_checksums=$(mktemp --suffix="-checksums.txt")

cleanup() {
  rm -f "${tmp_binary}" "${tmp_checksums}"
}
trap cleanup EXIT

printf '[*] Downloading war10ck...\n'
${FETCH_CMD} "${tmp_binary}" "${URL}/war10ck"

printf '[*] Downloading checksums...\n'
${FETCH_CMD} "${tmp_checksums}" "${URL}/checksums.txt"

printf '[*] Verifying checksum...\n'
expected=$(grep ' war10ck$' "${tmp_checksums}" | cut -d' ' -f1)
[[ -n "${expected}" ]] || die "war10ck entry not found in checksums.txt"

actual=$(sha256sum "${tmp_binary}" | cut -d' ' -f1)
if [[ "${actual}" != "${expected}" ]]; then
  printf '[!]   expected: %s\n' "${expected}" >&2
  printf '[!]   actual:   %s\n' "${actual}" >&2
  die "checksum mismatch"
fi
printf '[*] Checksum OK.\n'

printf '[*] Installing to /usr/local/bin/war10ck (requires sudo)...\n'
sudo install -m 0755 -o root -g root "${tmp_binary}" /usr/local/bin/war10ck

printf '[*] war10ck installed. Run: war10ck -h\n'
