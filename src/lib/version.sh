# shellcheck shell=bash
# shellcheck disable=SC2034  # Variables are used across bundled files

# Manually increment VERSION before tagging a new release.
readonly VERSION="v0.4.14"

version() {
  printf '%s\n' "${VERSION}"
}
