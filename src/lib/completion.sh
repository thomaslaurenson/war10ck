# shellcheck shell=bash

# If sourced (not executed directly), register bash completion and return
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Discover available modules and profiles by calling 'war10ck apply'. Results
  # are cached in _WAR10CK_MODULE_CACHE for the lifetime of the shell session
  # to avoid repeated network calls on every Tab press.
  _war10ck_get_targets() {
    if [[ -z "${_WAR10CK_MODULE_CACHE:-}" ]]; then
      local targets
      targets=$(war10ck apply 2>/dev/null | awk '/^  /{print $1}')
      [[ -n "$targets" ]] && _WAR10CK_MODULE_CACHE="$targets"
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

    # Second-level: module/profile name for all target-based subcommands
    case "${COMP_WORDS[1]}" in
      install|config|apply)
        mapfile -t COMPREPLY < <(compgen -W "$(_war10ck_get_targets)" -- "$cur")
        ;;
    esac
  }
  complete -F _war10ck_completions war10ck
  return
fi
