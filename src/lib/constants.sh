# shellcheck shell=bash
# shellcheck disable=SC2034  # Variables are used across bundled files

BASE_URL="https://war10ck.thomaslaurenson.com"

# SHA256 of the remote checksums.txt manifest. Replaced at bundle time by bundle.sh.
readonly CHECKSUMS_SHA256="dev"

# Build type - replaced at bundle time. "dev" enables local mode automatically.
readonly WAR10CK_BUILD="dev"

readonly VALID_SUBCOMMANDS=(
  version
  update
  install
  config
  apply
)
