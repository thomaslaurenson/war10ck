#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_deploy_remote_file "modules/emsdk/files/env.bash" "$HOME/.war10ck/env.d/emsdk"

w_log_info "emsdk config installed."
