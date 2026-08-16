#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_sudo_remove_file /usr/local/bin/mdbook-mermaid

w_log_info "mdbook-mermaid module uninstalled."
