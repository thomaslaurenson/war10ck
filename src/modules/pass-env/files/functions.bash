# function: per
#
# Shorthand for pass env run: run a command with the variables from one or more
# pass entries in its environment, without exporting anything into this shell.
#
# Arguments:
#   $@ - arguments passed straight to pass env run
per() {
  pass env run "$@"
}

# function: _w_per_complete
#
# Complete per by handing the line to pass-env's own completer.
#
# An alias would be shorter but gets no completion at all: bash looks the spec
# up by the first word on the line, and an alias is expanded after that lookup.
# So per is a function, and this rewrites the line as though it began
# "passenv run" before calling __passenv, which then completes entries, flags
# and the command after "--" exactly as it does for passenv. All four COMP_
# variables are rewritten because _init_completion rebuilds its word list from
# COMP_LINE and COMP_POINT as well as from COMP_WORDS and COMP_CWORD.
#
# __passenv is used rather than pass's own _pass: bash-completion loads _pass
# lazily on the first Tab after "pass", so it may not exist yet, whereas
# __passenv is registered eagerly from /etc/bash_completion.d/pass-env.
#
# Globals:
#   COMP_LINE, COMP_POINT, COMP_WORDS, COMP_CWORD - rewritten in place
#   COMPREPLY - filled by __passenv
# Returns:
#   0, with no candidates when pass-env's completion is not loaded
_w_per_complete() {
  declare -F __passenv > /dev/null 2>&1 || return 0

  local prefix="passenv run"
  local rest="${COMP_LINE#*per}"
  COMP_POINT=$(( COMP_POINT - (${#COMP_LINE} - ${#rest}) + ${#prefix} ))
  COMP_LINE="${prefix}${rest}"
  COMP_WORDS=(passenv run "${COMP_WORDS[@]:1}")
  COMP_CWORD=$(( COMP_CWORD + 1 ))
  __passenv
}

complete -F _w_per_complete per
