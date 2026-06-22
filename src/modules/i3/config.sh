#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

I3_DIR="$HOME/.config/i3"

# Deploy templates
w_deploy_remote_file "modules/i3/files/templates/config.base" "$I3_DIR/templates/config.base"
w_deploy_remote_file "modules/i3/files/templates/config.crossroads" "$I3_DIR/templates/config.crossroads"
w_deploy_remote_file "modules/i3/files/templates/config.brill" "$I3_DIR/templates/config.brill"

# Deploy runtime display controller
w_deploy_remote_file "modules/i3/files/scripts/display-setup.sh" "$I3_DIR/scripts/display-setup.sh"
chmod +x "$I3_DIR/scripts/display-setup.sh"

# Deploy workspace layout
w_deploy_remote_file "modules/i3/files/layouts/docked_ws2.json" "$I3_DIR/layouts/docked_ws2.json"

# Deploy and run compiler
w_deploy_remote_file "modules/i3/files/bundle.sh" "$I3_DIR/bundle.sh"
chmod +x "$I3_DIR/bundle.sh"
"$I3_DIR/bundle.sh"

w_log_info "i3 config installed."
