# shellcheck shell=bash

config() {
    local subcommand=$1; shift

    # If no subcommand provided, run all config functions
    if [ -z "$subcommand" ]; then
        for arg in "${VALID_CONFIG_ARGS[@]}"; do
            "config__$arg"
        done
        return
    fi

    # Check if the subcommand is a valid function and call it
    if type "config__$subcommand" >/dev/null 2>&1; then
        "config__$subcommand" "$@"
    else
        echo "[!] Invalid subcommand argument: $subcommand. Exiting."
        echo "[!] Valid arguments:"
        for arg in "${VALID_CONFIG_ARGS[@]}"; do
            echo "    $arg"
        done
        exit 1
    fi
}

config__rundmc() {
    echo "[*] Configuring rundmc..."
    $FETCH_CMD "$HOME/.war10ck/.rundmc" "$BASE_URL/config/rundmc"
    _verify_from_manifest "$HOME/.war10ck/.rundmc" "config/rundmc"

    if ! grep "# RUNDMC" "$HOME/.bashrc" > /dev/null; then
        {
            echo -e "\n# RUNDMC"
            echo -e "if [ -f $HOME/.war10ck/.rundmc ]; then"
            echo -e "    . $HOME/.war10ck/.rundmc"
            echo -e "fi"
        } >> "$HOME/.bashrc"
    fi
}

config__aliases() {
    echo "[*] Configuring aliases..."
    $FETCH_CMD "$HOME/.war10ck/.aliases" "$BASE_URL/config/aliases"
    _verify_from_manifest "$HOME/.war10ck/.aliases" "config/aliases"
}

config__bashrcd() {
    echo "[*] Configuring bashrc.d..."
    mkdir -p "$HOME/.war10ck/bashrc.d"
    chmod 700 "$HOME/.war10ck/bashrc.d"
}

config__commands() {
    echo "[*] Configuring commands..."
    $FETCH_CMD "$HOME/.war10ck/.commands" "$BASE_URL/config/commands"
    _verify_from_manifest "$HOME/.war10ck/.commands" "config/commands"
}

config__functions() {
    echo "[*] Configuring functions..."
    $FETCH_CMD "$HOME/.war10ck/.functions" "$BASE_URL/config/functions"
    _verify_from_manifest "$HOME/.war10ck/.functions" "config/functions"
}

config__gitconfig() {
    echo "[*] Configuring git..."
    $FETCH_CMD "$HOME/.gitconfig" "$BASE_URL/config/gitconfig"
    _verify_from_manifest "$HOME/.gitconfig" "config/gitconfig"
}

config__history() {
    echo "[*] Configuring history..."
    $FETCH_CMD "$HOME/.war10ck/.history" "$BASE_URL/config/history"
    _verify_from_manifest "$HOME/.war10ck/.history" "config/history"
}

config__tmux() {
    echo "[*] Configuring tmux..."
    $FETCH_CMD "$HOME/.war10ck/.tmux.conf" "$BASE_URL/config/tmux/tmux.conf"
    _verify_from_manifest "$HOME/.war10ck/.tmux.conf" "config/tmux/tmux.conf"
    mkdir -p "$HOME/.war10ck/.tmux"
    $FETCH_CMD "$HOME/.war10ck/.tmux/cer" "$BASE_URL/config/tmux/cer"
    _verify_from_manifest "$HOME/.war10ck/.tmux/cer" "config/tmux/cer"
    $FETCH_CMD "$HOME/.war10ck/.tmux/home" "$BASE_URL/config/tmux/home"
    _verify_from_manifest "$HOME/.war10ck/.tmux/home" "config/tmux/home"
}
