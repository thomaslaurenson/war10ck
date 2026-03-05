# shellcheck shell=bash
# shellcheck disable=SC2034  # Variables are used across bundled files
VERSION="dev"

BASE_URL="https://war10ck.thomaslaurenson.com"

# SHA256 of the remote checksums.txt manifest. Replaced at bundle time by bundle.sh.
CHECKSUMS_SHA256="dev"

VALID_SUBCOMMANDS=(
    version
    update
    config
    install
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
