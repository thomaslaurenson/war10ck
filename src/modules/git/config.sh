#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_deploy_functions git
w_deploy_remote_file "modules/git/files/gitconfig" \
  "$HOME/.war10ck/git/gitconfig"
w_deploy_remote_file "modules/git/files/both-hosts.gitconfig" \
  "$HOME/.war10ck/git/both-hosts.gitconfig"
w_deploy_remote_file "modules/git/files/no-identity.gitconfig" \
  "$HOME/.war10ck/git/no-identity.gitconfig"

w_log_info "git config installed."
