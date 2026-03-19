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
    mkdir -p "$HOME/.war10ck"
    $FETCH_CMD "$HOME/.war10ck/.rundmc" "$BASE_URL/config/rundmc"
    _verify_from_manifest "$HOME/.war10ck/.rundmc" "config/rundmc"

    if ! grep "# war10ck BEGIN" "$HOME/.bashrc" > /dev/null; then
        {
            echo -e "\n# war10ck BEGIN"
            echo -e "if [ -f $HOME/.war10ck/.rundmc ]; then"
            echo -e "    . $HOME/.war10ck/.rundmc"
            echo -e "fi"
            echo -e "# war10ck END"
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

    # Extract existing user information if .gitconfig exists
    local existing_name=""
    local existing_email=""
    local existing_signingkey=""

    if [ -f "$HOME/.gitconfig" ]; then
        echo "[*] Found existing .gitconfig, extracting user information..."
        existing_name=$(git config -f "$HOME/.gitconfig" user.name 2>/dev/null || echo "")
        existing_email=$(git config -f "$HOME/.gitconfig" user.email 2>/dev/null || echo "")
        existing_signingkey=$(git config -f "$HOME/.gitconfig" user.signingkey 2>/dev/null || echo "")
    fi

    # Fetch the base gitconfig template to a temporary location
    local temp_gitconfig
    temp_gitconfig=$(mktemp)
    echo "$BASE_URL/config/gitconfig"
    $FETCH_CMD "$temp_gitconfig" "$BASE_URL/config/gitconfig"
    _verify_from_manifest "$temp_gitconfig" "config/gitconfig"
    
    # Prompt for user information if not found in existing config
    local git_name="$existing_name"
    local git_email="$existing_email"
    local git_signingkey="$existing_signingkey"
    
    if [ -z "$git_name" ]; then
        echo -n "[?] Enter your Git name: "
        read -r git_name
    else
        echo "[*] Using existing Git name: $git_name"
    fi

    if [ -z "$git_email" ]; then
        echo -n "[?] Enter your Git email: "
        read -r git_email
    else
        echo "[*] Using existing Git email: $git_email"
    fi

    if [ -z "$git_signingkey" ]; then
        echo -n "[?] Enter your Git signing key path (or press Enter to skip): "
        read -r git_signingkey
    else
        echo "[*] Using existing Git signing key: $git_signingkey"
    fi

    # Update the template with user-specific values
    if [ -n "$git_name" ]; then
        sed -i "s|name = .*|name = $git_name|" "$temp_gitconfig"
    fi

    if [ -n "$git_email" ]; then
        sed -i "s|email = .*|email = $git_email|" "$temp_gitconfig"
    fi
    
    if [ -n "$git_signingkey" ]; then
        # Escape forward slashes in the path for sed
        local escaped_key="${git_signingkey//\//\\/}"
        sed -i "s|signingkey = .*|signingkey = $escaped_key|" "$temp_gitconfig"
    fi
    
    # Move the configured file to the final location
    mv "$temp_gitconfig" "$HOME/.gitconfig"
    echo "[*] Git configuration updated successfully"
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
