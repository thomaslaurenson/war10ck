# shellcheck shell=bash

# If sourced (not executed directly), register bash completion and return
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Discover available modules and profiles by calling 'war10ck apply'. Results
  # are cached in _WAR10CK_MODULE_CACHE for the lifetime of the shell session
  # to avoid repeated network calls on every Tab press.
  _war10ck_get_targets() {
    if [[ -z "${_WAR10CK_MODULE_CACHE:-}" ]]; then
      local targets
      # Match only lines whose name starts immediately after the two-space
      # indent. A profile's description is printed on its own line under a
      # blank name column, so a bare /^  / would offer its first word ("Custom
      # desktop environment" -> "Custom") as a completion target.
      targets=$(war10ck apply 2>/dev/null | awk '/^  [^ ]/{print $1}')
      [[ -n "${targets}" ]] && _WAR10CK_MODULE_CACHE="${targets}"
    fi
    printf '%s\n' "${_WAR10CK_MODULE_CACHE:-}"
  }

  # Provide Tab completion for war10ck: subcommands at position one, then
  # module and profile targets for the target-based subcommands.
  _war10ck_completions() {
    local cur
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    if (( COMP_CWORD == 1 )); then
      mapfile -t COMPREPLY < <(compgen -W "${VALID_SUBCOMMANDS[*]}" -- "${cur}")
      return
    fi

    case "${COMP_WORDS[1]}" in
      install|config|apply|uninstall)
        mapfile -t COMPREPLY < <(compgen -W "$(_war10ck_get_targets)" -- "${cur}")
        ;;
      clean)
        mapfile -t COMPREPLY < <(compgen -W "--apply" -- "${cur}")
        ;;
      status)
        ;;
    esac
  }
  complete -F _war10ck_completions war10ck
  return
fi
