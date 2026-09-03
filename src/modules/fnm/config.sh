#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_deploy_remote_file "modules/fnm/files/env.bash" "$HOME/.war10ck/env.d/fnm"

w_log_info "fnm config installed."
