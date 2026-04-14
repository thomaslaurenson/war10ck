# shellcheck shell=bash

version() {
    echo "$VERSION"
}

update() {
    echo "[*] Updating war10ck..."
    echo "[*] Current version: $VERSION"

    if [ ! -f "/usr/local/bin/war10ck" ]; then
        echo "[!] Could not find /usr/local/bin/war10ck. Exiting."
        exit 1
    fi

    echo "[*] Checking for updates..."
    local latest_version
    latest_version=$(curl -fsSL 2>/dev/null "https://api.github.com/repos/thomaslaurenson/war10ck/tags" | grep -m 1 '"name"' | sed 's/.*"name": *"v\?\([^"]*\)".*/\1/')

    if [ -z "$latest_version" ]; then
        echo "[!] Could not determine latest version from GitHub. Exiting."
        exit 1
    fi

    if [ "$VERSION" = "v$latest_version" ]; then
        echo "[*] Already up to date."
        return
    fi

    # Fetch the new release manifest over TLS. The pinned CHECKSUMS_SHA256 in
    # the installed binary is stale by definition during an update, so we trust
    # the TLS channel for manifest delivery and use the manifest to verify the
    # new binary — the same approach used by apt, Homebrew, etc.
    local manifest_tmp bin_tmp
    manifest_tmp=$(mktemp --suffix=.txt)
    $FETCH_CMD "$manifest_tmp" "$BASE_URL/checksums.txt"

    local expected_hash
    expected_hash=$(grep ' war10ck$' "$manifest_tmp" | cut -d' ' -f1)
    if [[ -z "$expected_hash" ]]; then
        echo "[!] Could not find war10ck hash in new manifest. Exiting."
        rm -f "$manifest_tmp"
        exit 1
    fi
    rm -f "$manifest_tmp"

    echo "[*] Updating war10ck... (requires sudo)"
    bin_tmp=$(mktemp --suffix=-war10ck)
    $FETCH_CMD "$bin_tmp" "$BASE_URL/war10ck"
    _verify_checksum "$bin_tmp" "$expected_hash"

    sudo mv "$bin_tmp" /usr/local/bin/war10ck
    sudo chmod 755 /usr/local/bin/war10ck
    sudo chown root:root /usr/local/bin/war10ck
    echo "[*] Updated to version $latest_version"
}

nuke() {
    echo "[*] Nuking war10ck..."
    echo "[*] Nuking configuration..."
    # Remove the war10ck block from "$HOME/.bashrc"
    # This deletes from '# war10ck BEGIN' to '# war10ck END'
    if [ -f "$HOME/.bashrc" ]; then
        sed -i '/# war10ck BEGIN/,/# war10ck END/d' "$HOME/.bashrc"
    fi
    rm -rf "$HOME/.war10ck/"
    echo "[*] Nuking binary... (requires sudo)"
    if [ -f "/usr/local/bin/war10ck" ]; then
        sudo rm -f "/usr/local/bin/war10ck"
    fi
    echo "[*] Nuke complete."
}
