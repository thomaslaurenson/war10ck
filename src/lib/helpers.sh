# shellcheck shell=bash

# Copy with reversed argument order (destination, source) to match fetch command conventions
_bcp() {
    cp "$2" "$1"
}

# Return 0 if the given string is a valid top-level subcommand
_is_valid_subcommand() {
    local subcommand=$1
    for valid_subcommand in "${VALID_SUBCOMMANDS[@]}"; do
        if [[ "$valid_subcommand" == "$subcommand" ]]; then
            return 0
        fi
    done
    return 1
}
