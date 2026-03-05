# shellcheck shell=bash

# Copy with reversed argument order (destination, source) to match fetch command conventions
_bcp() {
    cp "$2" "$1"
}

# Return 0 if the given string is a valid top-level subcommand
_is_valid_subcommand() {
    local subcommand=$1
    for valid_subcommand in "${VALID_SUBCOMMANDS[@]}"; do
        if [[ "$valid_subcommand" == "$subcommand" ]]; then
            return 0
        fi
    done
    return 1
}

# Verify a file's SHA256 against an expected hash. Removes the file and exits on mismatch.
# Skipped entirely when WAR10CK_SKIP_CHECKSUMS=1.
_verify_checksum() {
    local file=$1
    local expected=$2
    if [[ "${WAR10CK_SKIP_CHECKSUMS:-0}" == "1" ]]; then
        [[ "${WAR10CK_DEBUG:-0}" == "1" ]] && echo "[*] Checksum skipped: $(basename "$file")"
        return 0
    fi
    local actual
    actual=$(sha256sum "$file" | cut -d' ' -f1)
    if [[ "$actual" != "$expected" ]]; then
        echo "[!] Checksum mismatch: $file"
        echo "[!]   expected: $expected"
        echo "[!]   actual:   $actual"
        rm -f "$file"
        exit 1
    fi
    [[ "${WAR10CK_DEBUG:-0}" == "1" ]] && echo "[*] Checksum OK: $(basename "$file")"
    return 0
}

# Load the manifest and verify a file against it.
# Usage: _verify_from_manifest <file> <manifest_key>
# manifest_key is the relative path as it appears in checksums.txt (e.g. "install/docker.sh")
# Skipped entirely when WAR10CK_LOCAL=1 or WAR10CK_SKIP_CHECKSUMS=1.
_verify_from_manifest() {
    local file=$1
    local manifest_key=$2
    if [[ "${WAR10CK_LOCAL:-0}" == "1" || "${WAR10CK_SKIP_CHECKSUMS:-0}" == "1" ]]; then
        return 0
    fi
    if [[ -z "${WAR10CK_MANIFEST:-}" ]]; then
        echo "[!] Manifest not loaded. Cannot verify $manifest_key"
        exit 1
    fi
    local expected
    expected=$(echo "$WAR10CK_MANIFEST" | grep " ${manifest_key}$" | cut -d' ' -f1)
    if [[ -z "$expected" ]]; then
        echo "[!] No manifest entry found for: $manifest_key"
        exit 1
    fi
    _verify_checksum "$file" "$expected"
}
