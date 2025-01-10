#!/bin/bash


# Hardcoded files
URL_ALIASES="https://pub.thomaslaurenson.com/config/aliases"
URL_GITCONFIG="https://pub.thomaslaurenson.com/config/gitconfig"
URL_TMUXCONF="https://pub.thomaslaurenson.com/config/tmux.conf"

# Determine remote fetch command
if command -v curl &> /dev/null; then
    FETCH_CMD="curl -o"
elif command -v wget &> /dev/null; then
    FETCH_CMD="wget -O"
else
    echo "[!] No fetch command found... Exiting"
    exit 1
fi

# Version (set in GitHub Actions deploy.yml workflow)
PUB_VERSION=""
# Overwrite, or add, version in ~/.bashrc
if grep "# PUB VERSION" ~/.bashrc > /dev/null; then
    sed -i 's/export PUB_VERSION=v0.1.3
else
    {
        echo -e "\n# PUB VERSION"
        echo -e "export PUB_VERSION=v0.1.3
    }  >> ~/.bashrc
fi

# Fetch and add aliases file to ~/.bashrc
$FETCH_CMD "$HOME/.aliases" https://pub.thomaslaurenson.com/config/aliases
if ! grep "# CUSTOM ALIASES" ~/.bashrc > /dev/null; then
    {
        echo -e "\n# CUSTOM ALIASES"
        echo -e "if [ -f ~/.aliases ]; then"
        echo -e "    . ~/.aliases"
        echo -e "fi"
    }  >> ~/.bashrc
fi

# Fetch and add gitignore config
$FETCH_CMD "$HOME/.gitconfig" https://pub.thomaslaurenson.com/config/gitconfig

# Fetch and add tmux.conf file
$FETCH_CMD "$HOME/.tmux.conf" https://pub.thomaslaurenson.com/config/tmux.conf
tmux source ~/.tmux.conf
