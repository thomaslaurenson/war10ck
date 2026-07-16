# shellcheck shell=bash

# Update war10ck to the latest release.
# Fetches the new binary over TLS, verifies its checksum from the remote
# manifest, then installs it to /usr/local/bin/war10ck with sudo.
#
# Environment:
#   VERSION   - current installed version
#   BASE_URL  - base URL for fetching release assets
#   FETCH_CMD - fetch command to use (curl or wget)
update() {
  printf '[*] Updating war10ck...\n'
  printf '[*] Current version: %s\n' "${VERSION}"

  if [[ ! -f "/usr/local/bin/war10ck" ]]; then
    printf '[!] Could not find /usr/local/bin/war10ck. Exiting.\n' >&2
    exit 1
  fi

  printf '[*] Checking for updates...\n'
  local latest_version
  local _tmptags
  _tmptags=$(mktemp --suffix=-tags.json)
  w_download "https://api.github.com/repos/thomaslaurenson/war10ck/tags" "${_tmptags}"
  latest_version=$(grep -m 1 '"name"' "${_tmptags}" \
    | sed 's/.*"name": *"v\?\([^"]*\)".*/\1/')
  rm -f "${_tmptags}"

  if [[ -z "${latest_version}" ]]; then
    printf '[!] Could not determine latest version from GitHub. Exiting.\n' >&2
    exit 1
  fi

  # Strip the leading v for a numeric comparison. Only a strictly newer remote
  # version is installed: string equality alone would let a rolled-back server
  # (offering an older tag) "update" the local binary downwards.
  local current_version="${VERSION#v}"
  if [[ "${current_version}" == "${latest_version}" ]]; then
    printf '[*] Already up to date.\n'
    return
  fi
  local newer
  newer=$(printf '%s\n%s\n' "${current_version}" "${latest_version}" | sort -V | tail -n1)
  if [[ "${newer}" != "${latest_version}" ]]; then
    printf '[*] Installed version %s is newer than latest release %s. Nothing to do.\n' \
      "${VERSION}" "${latest_version}"
    return
  fi

  # Fetch the new release manifest over TLS. The pinned CHECKSUMS_SHA256 in
  # the installed binary is stale by definition during an update, so we trust
  # the TLS channel for manifest delivery and use the manifest to verify the
  # new binary - the same approach used by apt, Homebrew, etc.
  local manifest_tmp
  local bin_tmp
  manifest_tmp=$(mktemp --suffix=.txt)
  ${FETCH_CMD} "${manifest_tmp}" "${BASE_URL}/checksums.txt"

  local expected_hash
  expected_hash=$(grep ' war10ck$' "${manifest_tmp}" | cut -d' ' -f1)
  if [[ -z "${expected_hash}" ]]; then
    printf '[!] Could not find war10ck hash in new manifest. Exiting.\n' >&2
    rm -f "${manifest_tmp}"
    exit 1
  fi
  rm -f "${manifest_tmp}"

  printf '[*] Updating war10ck... (requires sudo)\n'
  bin_tmp=$(mktemp --suffix=-war10ck)
  ${FETCH_CMD} "${bin_tmp}" "${BASE_URL}/war10ck"

  # Verification is mandatory here and must not honour WAR10CK_SKIP_CHECKSUMS:
  # this replaces the root-owned binary, so an unverified swap is the worst
  # possible outcome. _verify_checksum would return early under --skip, so the
  # comparison is done inline instead.
  local actual_hash
  actual_hash=$(sha256sum "${bin_tmp}" | cut -d' ' -f1)
  if [[ "${actual_hash}" != "${expected_hash}" ]]; then
    printf '[!] Checksum mismatch on new binary. Refusing to update.\n' >&2
    printf '[!]   expected: %s\n' "${expected_hash}" >&2
    printf '[!]   actual:   %s\n' "${actual_hash}" >&2
    rm -f "${bin_tmp}"
    exit 1
  fi
  printf '[*] New binary verified.\n'

  sudo mv "${bin_tmp}" /usr/local/bin/war10ck
  sudo chmod 755 /usr/local/bin/war10ck
  sudo chown root:root /usr/local/bin/war10ck
  printf '[*] Updated to version %s\n' "${latest_version}"
}
