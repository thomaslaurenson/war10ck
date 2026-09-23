# Filen CLI, restricted to environment-variable authentication.
#
# The CLI tries four credential sources in order: --email/--password arguments,
# then FILEN_CLI_EMAIL/FILEN_CLI_PASSWORD, then an auth config file in the
# working directory or ~/.filen-cli, and finally an interactive prompt that
# offers to save what you type in the system keychain. Only the second of those
# is wanted here.
#
# The fallbacks are the problem, not the env vars: with FILEN_CLI_EMAIL unset
# the CLI does not fail, it quietly reaches for an auth config or a prompt. So
# the wrapper checks before handing over, and a forgotten `pass env run` becomes
# an error instead of a login from a credential file that should not exist.
#
# Nothing is ever written back: the CLI only saves credentials when they came
# from its own prompt, which this wrapper makes unreachable.
#
# A function rather than an alias: bash expands aliases in interactive shells
# only, so an alias would work at the prompt and be silently missing from a
# script or an ssh command.

# Run filen with credentials taken from the environment.
#
# Arguments:
#   $@ - Arguments passed to filen unchanged
filen() {
  # Subcommands that never authenticate. Gating these would mean needing
  # credentials to ask the version number, or to delete saved credentials.
  # Bare `filen` is not among them: it opens the REPL, which authenticates and
  # offers the keychain prompt. Note -v is verbosity here, not version.
  case "${1:-}" in
    -h|--help|help|-V|--version|logout|view-html-docs)
      command filen --skip-update "$@"
      return
      ;;
  esac

  if [[ -z "${FILEN_CLI_EMAIL:-}" || -z "${FILEN_CLI_PASSWORD:-}" ]]; then
    printf 'filen: FILEN_CLI_EMAIL and FILEN_CLI_PASSWORD are not set\n' >&2
    printf 'filen: this wrapper only authenticates from the environment\n' >&2
    printf 'try: pass env run env/filen.env -- filen %s\n' "$*" >&2
    return 1
  fi

  # --skip-update, and it has to precede the subcommand: the CLI self-updates
  # in place, which would replace a pinned, checksum-verified binary with an
  # unverified one, and fail anyway against root-owned /usr/local/bin. Run
  # `command filen` to let the updater have its way.
  command filen --skip-update "$@"
}
