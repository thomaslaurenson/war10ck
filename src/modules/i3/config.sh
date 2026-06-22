#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

I3_DIR="$HOME/.war10ck/i3"

# Deploy templates
w_deploy_remote_file "modules/i3/files/templates/config.base" "$I3_DIR/templates/config.base"
w_deploy_remote_file "modules/i3/files/templates/config.crossroads" "$I3_DIR/templates/config.crossroads"
w_deploy_remote_file "modules/i3/files/templates/config.brill" "$I3_DIR/templates/config.brill"

# Deploy runtime display controller
w_deploy_remote_file "modules/i3/files/scripts/display-setup.sh" "$I3_DIR/scripts/display-setup.sh"
w_make_executable "$I3_DIR/scripts/display-setup.sh"

# Deploy workspace layout
w_deploy_remote_file "modules/i3/files/layouts/docked_ws2.json" "$I3_DIR/layouts/docked_ws2.json"

# Bundle: compile base + host template into final config
HOST=$(hostname)
if [[ ! -f "$I3_DIR/templates/config.$HOST" ]]; then
    w_log_error "No i3 template found for host '$HOST' (expected $I3_DIR/templates/config.$HOST)"
    exit 1
fi
cat "$I3_DIR/templates/config.base" "$I3_DIR/templates/config.$HOST" > "$I3_DIR/config"
chmod 644 "$I3_DIR/config"
w_log_info "Compiled i3 config for host '$HOST'"

# Symlink compiled config into i3's expected location
mkdir -p "$HOME/.config/i3"
w_symlink "$I3_DIR/config" "$HOME/.config/i3/config"

w_log_info "i3 config installed."
