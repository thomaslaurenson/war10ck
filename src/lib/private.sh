# shellcheck shell=bash

# Copy with reversed argument order (destination, source) to match fetch command conventions.
#
# Arguments:
#   $1 - Destination path
#   $2 - Source path
_bcp() {
  cp "$2" "$1"
}
export -f _bcp

# Return 0 if the given string is a valid top-level subcommand, 1 otherwise.
#
# Arguments:
#   $1 - Subcommand string to validate
# Returns:
#   0 if valid, 1 if not
_is_valid_subcommand() {
  local subcommand=$1
  for valid_subcommand in "${VALID_SUBCOMMANDS[@]}"; do
    if [[ "${valid_subcommand}" == "${subcommand}" ]]; then
      return 0
    fi
  done
  return 1
}

# Verify a file's SHA256 against an expected hash. Removes the file and exits on mismatch.
# Skipped entirely when WAR10CK_SKIP_CHECKSUMS=1.
#
# Arguments:
#   $1 - Path to the file to verify
#   $2 - Expected SHA256 hash string
# Returns:
#   0 on success, exits 1 on mismatch
_verify_checksum() {
  local file=$1
  local expected=$2
  if [[ "${WAR10CK_SKIP_CHECKSUMS:-0}" == "1" ]]; then
    [[ "${WAR10CK_DEBUG:-0}" == "1" ]] && printf '[*] Checksum skipped: %s\n' "$(basename "${file}")"
    return 0
  fi
  local actual
  actual=$(sha256sum "${file}" | cut -d' ' -f1)
  if [[ "${actual}" != "${expected}" ]]; then
    printf '[!] Checksum mismatch: %s\n' "${file}" >&2
    printf '[!]   expected: %s\n' "${expected}" >&2
    printf '[!]   actual:   %s\n' "${actual}" >&2
    rm -f "${file}"
    exit 1
  fi
  [[ "${WAR10CK_DEBUG:-0}" == "1" ]] && printf '[*] Checksum OK: %s\n' "$(basename "${file}")"
  return 0
}

# Verify a file against its entry in the loaded manifest.
# Skipped entirely when WAR10CK_LOCAL=1 or WAR10CK_SKIP_CHECKSUMS=1.
#
# Arguments:
#   $1 - Path to the file to verify
#   $2 - Manifest key (relative path as it appears in checksums.txt)
# Environment:
#   WAR10CK_MANIFEST - loaded manifest content
#   WAR10CK_LOCAL    - when 1, skip verification
#   WAR10CK_SKIP_CHECKSUMS - when 1, skip verification
# Returns:
#   0 on success, exits 1 if manifest is missing or entry not found
_verify_from_manifest() {
  local file=$1
  local manifest_key=$2
  if [[ "${WAR10CK_LOCAL:-0}" == "1" || "${WAR10CK_SKIP_CHECKSUMS:-0}" == "1" ]]; then
    return 0
  fi
  if [[ -z "${WAR10CK_MANIFEST:-}" ]]; then
    printf '[!] Manifest not loaded. Cannot verify %s\n' "${manifest_key}" >&2
    exit 1
  fi
  local expected
  expected=$(printf '%s' "${WAR10CK_MANIFEST}" | grep " ${manifest_key}$" | cut -d' ' -f1)
  if [[ -z "${expected}" ]]; then
    printf '[!] No manifest entry found for: %s\n' "${manifest_key}" >&2
    exit 1
  fi
  _verify_checksum "${file}" "${expected}"
}
