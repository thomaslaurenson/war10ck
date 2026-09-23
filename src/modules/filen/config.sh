#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_deploy_functions filen

w_log_info "filen config installed."
w_log_info "filen now requires FILEN_CLI_EMAIL and FILEN_CLI_PASSWORD in the environment."
