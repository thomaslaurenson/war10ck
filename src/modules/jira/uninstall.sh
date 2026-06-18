#!/usr/bin/env bash


set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_remove_functions jira

w_log_info "jira module uninstalled."
