#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# pass-env ships its own uninstaller, laid down next to the install manifest
# that records every file the installer placed. Reimplementing the removal here
# would mean tracking those paths in two repos, so the shipped script is used
# instead. It lands in the system directory or the user one depending on how
# the install was run, so both are checked.
PASS_ENV_UNINSTALLERS=(
    "/usr/local/share/pass-env/pass-env-uninstall.sh"
    "$HOME/.local/share/pass-env/pass-env-uninstall.sh"
)

_found=""
for _candidate in "${PASS_ENV_UNINSTALLERS[@]}"; do
    if [[ -f "$_candidate" ]]; then
        _found="$_candidate"
        break
    fi
done

if [[ -z "$_found" ]]; then
    w_log_error "No pass-env uninstaller found in:"
    for _candidate in "${PASS_ENV_UNINSTALLERS[@]}"; do
        w_log_error "  $_candidate"
    done
    w_log_error "pass-env may not be installed, or was installed with --no-uninstall."
    exit 1
fi

# Run without sudo: the uninstaller escalates per path only where the parent
# directory is not user-writable, and it needs the real $HOME to strip its
# block from the shell RC files.
w_log_info "Running $_found"
bash "$_found"

# pass, gnupg, and fzf are left installed. They are general-purpose tools that
# predate this module for most users, and removing gnupg in particular would
# break far more than pass-env.
w_log_info "pass-env module uninstalled (pass, gnupg and fzf were left installed)."
