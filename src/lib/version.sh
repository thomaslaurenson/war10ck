# shellcheck shell=bash
# shellcheck disable=SC2034  # Variables are used across bundled files

# Manually increment VERSION before tagging a new release.
VERSION="v0.4.13"

version() {
    echo "$VERSION"
}
