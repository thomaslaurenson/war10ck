# shellcheck shell=bash
# shellcheck disable=SC2034  # Variables are used across bundled files

# Manually increment VERSION before tagging a new release.
readonly VERSION="v0.7.0"

# Print the current war10ck version, appending a -dev suffix for dev builds.
#
# Environment:
#   WAR10CK_BUILD - "dev" appends the -dev suffix; any other value prints the bare version
version() {
  local display="${VERSION}"
  if [[ "${WAR10CK_BUILD:-dev}" == "dev" ]]; then
    display="${display}-dev"
  fi
  printf '%s\n' "${display}"
}
