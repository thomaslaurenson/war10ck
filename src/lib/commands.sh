# shellcheck shell=bash

version() {
    echo "$VERSION"
}

update() {
    echo "[*] UPDATE..."
    if [ ! -f "/usr/local/bin/war10ck" ]; then
        echo "[!] Could not find /usr/local/bin/war10ck. Exiting."
        exit 1
    fi

    echo "[*] Checking for updates..."
    local latest_version
    latest_version=$(curl -s "https://api.github.com/repos/thomaslaurenson/war10ck/tags" | grep -m 1 '"name"' | sed 's/.*"name": *"v\?\([^"]*\)".*/\1/')

    if [ -z "$latest_version" ]; then
        echo "[!] Could not determine latest version from GitHub. Exiting."
        exit 1
    fi

    if [ "$VERSION" = "v$latest_version" ]; then
        echo "[*] Already up to date."
        return
    fi

    echo "[*] Updating war10ck... requires sudo!"
    $FETCH_CMD "/tmp/war10ck" "$BASE_URL/war10ck"
    echo "[*] Installing to path"
    sudo mv /tmp/war10ck /usr/local/bin/war10ck
    echo "[*] Setting executable permissions"
    sudo chmod +x /usr/local/bin/war10ck
    echo "[*] Setting executable ownership"
    sudo chown root:root /usr/local/bin/war10ck
    echo "[*] Updated to version $latest_version"
}

nuke() {
    echo "[*] Nuking war10ck..."
    echo "[*] Nuking configuration..."
    # Remove the RUNDMC block from "$HOME/.bashrc"
    # This deletes from '# RUNDMC' to the first 'fi'
    if [ -f "$HOME/.bashrc" ]; then
        sed -i '/# RUNDMC/,/fi/d' "$HOME/.bashrc"
    fi
    rm -rf "$HOME/.war10ck/"
    echo "[*] Nuking binary... (requires sudo)"
    if [ -f "/usr/local/bin/war10ck" ]; then
        sudo rm -f "/usr/local/bin/war10ck"
    fi
    echo "[*] Nuke complete."
}
