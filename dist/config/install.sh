#!/bin/bash


PUB_URL="https://pub.thomaslaurenson.com/config"

IS_LOCAL=false
if [ "$IS_LOCAL" = true ]; then
    cd "$(dirname "$0")" || exit 1
    PUB_URL="."
fi

# Hardcoded files
URL_ALIASES="$PUB_URL/aliases"
URL_FUNCTIONS="$PUB_URL/functions"
URL_GITCONFIG="$PUB_URL/gitconfig"
URL_TMUX_CONF="$PUB_URL/tmux/tmux.conf"
URL_TMUX_CER="$PUB_URL/tmux/cer"
URL_TMUX_HOMELAB="$PUB_URL/tmux/homelab"

# Determine fetch command
if "$IS_LOCAL" = true; then
    FETCH_CMD="backwards_cp"
elif command -v curl &> /dev/null; then
    FETCH_CMD="curl -s -o"
elif command -v wget &> /dev/null; then
    FETCH_CMD="wget -q -O"
else
    echo "[!] No fetch command found... Exiting"
    exit 1
fi

# Define backwards_cp which switches source and destination
backwards_cp() {
    cp "$2" "$1"
}

# Version (this is set in GitHub Actions deploy.yml workflow)
PUB_VERSION=""
echo "[*] Setting pub version: $PUB_VERSION"
# Overwrite, or add, version in ~/.bashrc
if grep "# PUB VERSION" ~/.bashrc > /dev/null; then
    sed -i "s/export PUB_VERSION=.*/export PUB_VERSION=$PUB_VERSION/" ~/.bashrc
else
    {
        echo -e "\n# PUB VERSION"
        echo -e "export PUB_VERSION=$PUB_VERSION"
    }  >> ~/.bashrc
fi

# Fetch and add functions file to ~/.bashrc
echo "[*] Configuring functions..."
$FETCH_CMD "$HOME/.functions" "$URL_FUNCTIONS"
if ! grep "# CUSTOM FUNCTIONS" ~/.bashrc > /dev/null; then
    {
        echo -e "\n# CUSTOM FUNCTIONS"
        echo -e "if [ -f ~/.functions ]; then"
        echo -e "    . ~/.functions"
        echo -e "fi"
    }  >> ~/.bashrc
fi

# Fetch and add aliases file to ~/.bashrc
echo "[*] Configuring aliases..."
$FETCH_CMD "$HOME/.aliases" "$URL_ALIASES"
if ! grep "# CUSTOM ALIASES" ~/.bashrc > /dev/null; then
    {
        echo -e "\n# CUSTOM ALIASES"
        echo -e "if [ -f ~/.aliases ]; then"
        echo -e "    . ~/.aliases"
        echo -e "fi"
    }  >> ~/.bashrc
fi

# Fetch gitignore config
echo "[*] Configuring git..."
$FETCH_CMD "$HOME/.gitconfig" "$URL_GITCONFIG"

# Fetch tmux configuration and sessions configurations
echo "[*] Configuring tmux..."
mkdir -p "$HOME/.tmux"
$FETCH_CMD "$HOME/.tmux/tmux.conf" "$URL_TMUX_CONF"
$FETCH_CMD "$HOME/.tmux/cer" "$URL_TMUX_CER"
$FETCH_CMD "$HOME/.tmux/homelab" "$URL_TMUX_HOMELAB"
