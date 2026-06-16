# shellcheck shell=bash
# shellcheck disable=SC2034  # Variables are used across bundled files

# Manually increment VERSION before tagging a new release.
readonly VERSION="v0.4.14"

version() {
  local display="${VERSION}"
  if [[ "${WAR10CK_BUILD:-dev}" == "dev" ]]; then
    display="${display}-dev"
  fi
  printf '%s\n' "${display}"
}
