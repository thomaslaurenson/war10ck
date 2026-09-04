# Claude Code configuration profiles.
#
# A profile is a complete configuration root: its own credentials, settings,
# history, projects and plugins. Switching profile switches account, not just
# settings, so each one authenticates separately the first time it is used.
# Plain "claude" is untouched and goes on using ~/.claude.
#
# A function rather than an alias: bash expands aliases in interactive shells
# only, so an alias would work at the prompt and be silently missing from a
# script or an ssh command.
#
# clap is short for claude profiles. It is typed often enough to be worth four
# characters, and short enough that tab completion never has to help.

# Run claude against a named configuration root under ~/.claude.d.
#
# With no profile, lists the profiles that already exist.
#
# Arguments:
#   $1 - Profile name
#   $@ - Remaining arguments, passed to claude unchanged
clap() {
  local root="${HOME}/.claude.d"
  local profile=${1:-}

  if [[ -z "${profile}" || "${profile}" == -* ]]; then
    printf 'Usage: clap <profile> [claude arguments]\n' >&2
    local dirs=() dir
    for dir in "${root}"/*/; do
      [[ -d "${dir}" ]] || continue
      dirs+=("$(basename "${dir}")")
    done
    if (( ${#dirs[@]} > 0 )); then
      printf '\nProfiles in %s:\n' "${root}" >&2
      printf '  %s\n' "${dirs[@]}" >&2
    else
      printf '\nNo profiles yet in %s\n' "${root}" >&2
    fi
    return 1
  fi

  # The same character set war10ck accepts in a module name. The name becomes a
  # directory, so a stray slash would put the configuration root somewhere
  # other than under ~/.claude.d.
  if [[ ! "${profile}" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
    printf 'clap: invalid profile name: %s\n' "${profile}" >&2
    return 1
  fi
  shift

  # Announced rather than created quietly. A mistyped name is otherwise
  # indistinguishable from a real profile, and the only symptom is being asked
  # to log in to an account you thought was already authenticated.
  local dir="${root}/${profile}"
  if [[ ! -d "${dir}" ]]; then
    printf 'clap: new profile "%s", it will ask you to authenticate\n' "${profile}" >&2
    mkdir -p "${dir}" || return 1
  fi

  CLAUDE_CONFIG_DIR="${dir}" claude "$@"
}
