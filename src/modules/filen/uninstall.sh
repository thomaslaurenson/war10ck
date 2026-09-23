#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

readonly FILEN_CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/filen-cli"
readonly FILEN_HOME_DIR="${HOME}/.filen-cli"

# The keychain is outside this module's reach: the wrapper blocks the prompt
# that would save anything there, but a login made before it was in place
# survives an uninstall, and `filen logout` is the only thing that clears it.
if command -v filen &> /dev/null; then
  w_log_info "Saved keychain credentials, if any, outlive this: clear them with 'filen logout'."
fi

w_sudo_remove_file /usr/local/bin/filen

w_remove_functions filen

# No mount point is removed here, deliberately: it is whichever directory was
# passed to `filen mount`, and a recursive delete against a drive that is still
# mounted would take the cloud contents with it.

# Logs, and the managed Rclone the CLI downloads for `filen mount`.
w_remove_dir "${FILEN_CONFIG_DIR}"

# Should hold no credentials at all - the wrapper only ever authenticates from
# the environment, and the CLI saves nothing unless it prompted for the login
# itself. Removed anyway, because an auth config here is exactly the stored
# secret this module exists to avoid, and it is also where the upstream
# installer puts its copy of the binary.
w_remove_dir "${FILEN_HOME_DIR}"

w_log_info "filen module uninstalled."
