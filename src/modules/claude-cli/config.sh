#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_deploy_remote_file "modules/claude-cli/files/env.bash" "$HOME/.war10ck/env.d/claude-cli"

w_log_info "claude-cli config installed."
