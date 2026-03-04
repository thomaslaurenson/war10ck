# shellcheck shell=bash

install() {
    echo "[*] INSTALL..."
    local subcommand=$1; shift

    # Check if the subcommand is a valid function and call it
    if type "install__$subcommand" >/dev/null 2>&1; then
        "install__$subcommand" "$@"
    else
        echo "[!] Invalid subcommand argument: $subcommand. Exiting."
        echo "[!] Valid arguments:"
        for arg in "${VALID_INSTALL_ARGS[@]}"; do
            echo "    $arg"
        done
        exit 1
    fi
}

# Helper: fetch an install script from the remote, verify it against the manifest,
# then execute it with the supplied privilege prefix (e.g. "sudo" or "").
_install__fetch_and_run() {
    local manifest_key=$1  # e.g. "install/docker.sh"
    local privilege=$2     # e.g. "sudo" or ""
    local script_name
    script_name=$(basename "$manifest_key")
    local _tmpfile
    _tmpfile=$(mktemp --suffix="-${script_name}")
    $FETCH_CMD "$_tmpfile" "$BASE_URL/$manifest_key"
    _verify_from_manifest "$_tmpfile" "$manifest_key"
    ${privilege:+$privilege} bash "$_tmpfile"
    rm -f "$_tmpfile"
}

install__docker() {
    echo "[*] Installing Docker..."
    if [ -f "/usr/bin/docker" ]; then
        echo "[!] Docker already installed. Skipping installation."
    else
        _install__fetch_and_run "install/docker.sh" "sudo"
        echo "[*] Docker installation complete."
        echo "[*] Please log out and back in to apply group changes."
    fi
}

install__ghidra() {
    echo "[*] Installing Ghidra..."
    _install__fetch_and_run "install/ghidra.sh" "sudo"
    echo "[*] Ghidra installation complete."
}

install__golang() {
    echo "[*] Installing Go..."
    _install__fetch_and_run "install/golang.sh" "sudo"
    echo "[*] Go installation complete."
}

install__hugo() {
    echo "[*] Installing Hugo..."
    _install__fetch_and_run "install/hugo.sh" "sudo"
    echo "[*] Hugo installation complete."
}

install__java() {
    echo "[*] Installing Java..."
    _install__fetch_and_run "install/java.sh" "sudo"
    echo "[*] Java installation complete."
}

install__jira() {
    echo "[*] Installing Jira CLI..."
    _install__fetch_and_run "install/jira.sh" "sudo"
    echo "[*] Jira CLI installation complete."
}

install__mitmproxy() {
    echo "[*] Installing mitmproxy..."
    _install__fetch_and_run "install/mitmproxy.sh" "sudo"
    echo "[*] mitmproxy installation complete."
}

install__mpqeditor() {
    echo "[*] Installing MPQ Editor..."
    _install__fetch_and_run "install/mpqeditor.sh" "sudo"
    echo "[*] MPQ Editor installation complete."
}

install__nvm() {
    echo "[*] Installing nvm..."
    _install__fetch_and_run "install/nvm.sh" ""
    echo "[*] nvm installation complete."
}

install__packages() {
    echo "[*] Installing packages..."
    local package_list=(
        curl
        gh
        jq
        make
        python3-pip
        python3-venv
        shellcheck
        tree
        vim
        wget
    )
    sudo apt -y install "${package_list[@]}"
}

install__signal() {
    echo "[*] Installing Signal..."
    _install__fetch_and_run "install/signal.sh" "sudo"
    echo "[*] Signal installation complete."
}

install__terraform() {
    echo "[*] Installing Terraform..."
    _install__fetch_and_run "install/terraform.sh" "sudo"
    echo "[*] Terraform installation complete."
}

install__uv() {
    echo "[*] Installing UV..."
    _install__fetch_and_run "install/uv.sh" ""
    echo "[*] UV installation complete."
}

install__vscode() {
    echo "[*] Installing Visual Studio Code..."
    if command -v code &> /dev/null; then
        echo "[!] Visual Studio Code already installed. Skipping installation."
    else
        _install__fetch_and_run "install/vscode.sh" "sudo"
        echo "[*] Visual Studio Code installation complete."
    fi
}
