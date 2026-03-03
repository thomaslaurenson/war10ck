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

install__docker() {
    echo "[*] Installing Docker..."
    if [ -f "/usr/bin/docker" ]; then
        echo "[!] Docker already installed. Skipping installation."
    else
        $FETCH_CMD "/tmp/docker.sh" "$BASE_URL/install/docker.sh"
        sudo bash /tmp/docker.sh
        echo "[*] Docker installation complete."
        echo "[*] Please log out and back in to apply group changes."
        rm -f /tmp/docker.sh
    fi
}

install__ghidra() {
    echo "[*] Installing Ghidra..."
    $FETCH_CMD "/tmp/ghidra.sh" "$BASE_URL/install/ghidra.sh"
    sudo bash /tmp/ghidra.sh
    echo "[*] Ghidra installation complete."
    rm -f /tmp/ghidra.sh
}

install__golang() {
    echo "[*] Installing Go..."
    $FETCH_CMD "/tmp/golang.sh" "$BASE_URL/install/golang.sh"
    sudo bash /tmp/golang.sh
    echo "[*] Go installation complete."
    rm -f /tmp/golang.sh
}

install__hugo() {
    echo "[*] Installing Hugo..."
    $FETCH_CMD "/tmp/hugo.sh" "$BASE_URL/install/hugo.sh"
    sudo bash /tmp/hugo.sh
    echo "[*] Hugo installation complete."
    rm -f /tmp/hugo.sh
}

install__java() {
    echo "[*] Installing Java..."
    $FETCH_CMD "/tmp/java.sh" "$BASE_URL/install/java.sh"
    sudo bash /tmp/java.sh
    echo "[*] Java installation complete."
    rm -f /tmp/java.sh
}

install__jira() {
    echo "[*] Installing Jira CLI..."
    $FETCH_CMD "/tmp/jira.sh" "$BASE_URL/install/jira.sh"
    sudo bash /tmp/jira.sh
    echo "[*] Jira CLI installation complete."
    rm -f /tmp/jira.sh
}

install__mitmproxy() {
    echo "[*] Installing mitmproxy..."
    $FETCH_CMD "/tmp/mitmproxy.sh" "$BASE_URL/install/mitmproxy.sh"
    sudo bash /tmp/mitmproxy.sh
    echo "[*] mitmproxy installation complete."
    rm -f /tmp/mitmproxy.sh
}

install__mpqeditor() {
    echo "[*] Installing MPQ Editor..."
    $FETCH_CMD "/tmp/mpqeditor.sh" "$BASE_URL/install/mpqeditor.sh"
    sudo bash /tmp/mpqeditor.sh
    echo "[*] MPQ Editor installation complete."
    rm -f /tmp/mpqeditor.sh
}

install__nvm() {
    echo "[*] Installing nvm..."
    $FETCH_CMD "/tmp/nvm.sh" "$BASE_URL/install/nvm.sh"
    bash /tmp/nvm.sh
    echo "[*] nvm installation complete."
    rm -f /tmp/nvm.sh
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
    $FETCH_CMD "/tmp/signal.sh" "$BASE_URL/install/signal.sh"
    sudo bash /tmp/signal.sh
    echo "[*] Signal installation complete."
    rm -f /tmp/signal.sh
}

install__terraform() {
    echo "[*] Installing Terraform..."
    $FETCH_CMD "/tmp/terraform.sh" "$BASE_URL/install/terraform.sh"
    sudo bash /tmp/terraform.sh
    echo "[*] Terraform installation complete."
    rm -f /tmp/terraform.sh
}

install__uv() {
    echo "[*] Installing UV..."
    $FETCH_CMD "/tmp/uv.sh" "$BASE_URL/install/uv.sh"
    bash /tmp/uv.sh
    echo "[*] UV installation complete."
    rm -f /tmp/uv.sh
}

install__vscode() {
    echo "[*] Installing Visual Studio Code..."
    if command -v code &> /dev/null; then
        echo "[!] Visual Studio Code already installed. Skipping installation."
    else
        $FETCH_CMD "/tmp/vscode.sh" "$BASE_URL/install/vscode.sh"
        sudo bash /tmp/vscode.sh
        echo "[*] Visual Studio Code installation complete."
        rm -f /tmp/vscode.sh
    fi
}
