#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

GPIPE_DIR="$HOME/.war10ck/gpipe.d"

# Only the registry is removed. The tools it lists were installed by their own
# installers and are left in place, since nothing here knows how to remove them.
w_remove_dir "$GPIPE_DIR"

w_log_info "gpipe registry uninstalled (listed tools were left installed)."
