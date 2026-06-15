# shellcheck shell=bash

# If sourced (not executed directly), register bash completion and return
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Discover available modules by calling 'war10ck list'. Results are cached
    # in _WAR10CK_MODULE_CACHE for the lifetime of the shell session to avoid
    # repeated network calls on every Tab press.
    _war10ck_get_modules() {
        if [[ -z "${_WAR10CK_MODULE_CACHE:-}" ]]; then
            local modules
            modules=$(war10ck list 2>/dev/null | awk '/^  - /{print $2}')
            [[ -n "$modules" ]] && _WAR10CK_MODULE_CACHE="$modules"
        fi
        echo "${_WAR10CK_MODULE_CACHE:-}"
    }

    _war10ck_completions() {
        local cur
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"

        # Top-level subcommands
        if [[ $COMP_CWORD -eq 1 ]]; then
            mapfile -t COMPREPLY < <(compgen -W "${VALID_SUBCOMMANDS[*]}" -- "$cur")
            return
        fi

        # Second-level: module name for all module-based subcommands
        case "${COMP_WORDS[1]}" in
            install|config|setup|launch)
                mapfile -t COMPREPLY < <(compgen -W "$(_war10ck_get_modules)" -- "$cur")
                ;;
        esac
    }
    complete -F _war10ck_completions war10ck
    return
fi
