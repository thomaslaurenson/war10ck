# shellcheck shell=bash

# If sourced (not executed directly), register bash completion and return
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    _war10ck_completions() {
        local cur
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"

        # Top-level subcommands
        if [[ $COMP_CWORD -eq 1 ]]; then
            mapfile -t COMPREPLY < <(compgen -W "${VALID_SUBCOMMANDS[*]}" -- "$cur")
            return
        fi

        # Second-level subcommands
        case "${COMP_WORDS[1]}" in
            config)
                mapfile -t COMPREPLY < <(compgen -W "${VALID_CONFIG_ARGS[*]}" -- "$cur")
                ;;
            install)
                mapfile -t COMPREPLY < <(compgen -W "${VALID_INSTALL_ARGS[*]}" -- "$cur")
                ;;
        esac
    }
    complete -F _war10ck_completions war10ck
    return
fi
