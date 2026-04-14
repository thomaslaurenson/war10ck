# shellcheck shell=bash

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
