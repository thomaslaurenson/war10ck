# shellcheck shell=bash
# shellcheck disable=SC2034  # Variables are used across bundled files

BASE_URL="https://war10ck.thomaslaurenson.com"

# SHA256 of the remote checksums.txt manifest. Replaced at bundle time by bundle.sh.
CHECKSUMS_SHA256="dev"

VALID_SUBCOMMANDS=(
    version
    update
    config
    install
    setup
    launch
    list
    nuke
)
