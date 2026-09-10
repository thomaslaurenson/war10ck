#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

SSH_CONFIG="${HOME}/.ssh/config"
SSH_CONFIG_D="${HOME}/.ssh/config.d"

# Deployed before the base config below, which returns early on any machine that
# already has an ~/.ssh/config. The agent fragment has nothing to do with that
# file and has to reach those machines too.
w_deploy_remote_file "modules/ssh/files/env.bash" "$HOME/.war10ck/env.d/ssh"

# Create ~/.ssh with correct permissions if it does not exist
if [[ ! -d "${HOME}/.ssh" ]]; then
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  w_log_info "Created ${HOME}/.ssh"
fi

# Create the config.d directory; holds unmanaged host entries
if [[ ! -d "${SSH_CONFIG_D}" ]]; then
  mkdir -p "${SSH_CONFIG_D}"
  chmod 700 "${SSH_CONFIG_D}"
  w_log_info "Created ${SSH_CONFIG_D}"
fi

# Deploy the base config only if it does not already exist.
# We never overwrite; existing config may contain entries we don't know about.
if [[ -f "${SSH_CONFIG}" ]]; then
  w_log_info "${HOME}/.ssh/config already exists, skipping to avoid overwriting."
  w_log_info "To deploy the war10ck base config manually, run:"
  w_log_info "  cp \$BASE_URL/modules/ssh/files/config ${HOME}/.ssh/config"
  exit 0
fi

w_deploy_remote_file "modules/ssh/files/config" "${SSH_CONFIG}"
chmod 600 "${SSH_CONFIG}"
w_log_info "SSH base config deployed to ${SSH_CONFIG}"
