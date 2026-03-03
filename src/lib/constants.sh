# shellcheck shell=bash
# shellcheck disable=SC2034  # Variables are used across bundled files
VERSION="dev"

BASE_URL="https://war10ck.thomaslaurenson.com"

VALID_SUBCOMMANDS=(
    version
    update
    config
    install
    remove
    nuke
)

VALID_CONFIG_ARGS=(
    rundmc
    aliases
    bashrcd
    commands
    functions
    gitconfig
    history
    tmux
)

VALID_INSTALL_ARGS=(
    docker
    ghidra
    golang
    hugo
    java
    jira
    mitmproxy
    mpqeditor
    nvm
    packages
    signal
    terraform
    uv
    vscode
)
