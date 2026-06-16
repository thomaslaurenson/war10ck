#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_install git

# Deploy gitconfig template, preserving any existing user values
local_gitconfig="$HOME/.gitconfig"

existing_name=""
existing_email=""
existing_signingkey=""

if [[ -f "${local_gitconfig}" ]]; then
  w_log_info "Found existing .gitconfig, extracting user values..."
  existing_name=$(git config -f "${local_gitconfig}" user.name 2>/dev/null || true)
  existing_email=$(git config -f "${local_gitconfig}" user.email 2>/dev/null || true)
  existing_signingkey=$(git config -f "${local_gitconfig}" user.signingkey 2>/dev/null || true)
fi

tmp_gitconfig=$(mktemp --suffix=".gitconfig")
w_deploy_remote_file "modules/git/files/gitconfig" "${tmp_gitconfig}"

if [[ -z "${existing_name}" ]]; then
  printf '[?] Enter your Git name: '
  read -r existing_name
else
  w_log_info "Using existing Git name: ${existing_name}"
fi

if [[ -z "${existing_email}" ]]; then
  printf '[?] Enter your Git email: '
  read -r existing_email
else
  w_log_info "Using existing Git email: ${existing_email}"
fi

if [[ -z "${existing_signingkey}" ]]; then
  printf '[?] Enter your Git signing key path (or press Enter to skip): '
  read -r existing_signingkey
else
  w_log_info "Using existing Git signing key: ${existing_signingkey}"
fi

sed -i "s|name = YOUR_NAME|name = ${existing_name}|"   "${tmp_gitconfig}"
sed -i "s|email = YOUR_EMAIL|email = ${existing_email}|" "${tmp_gitconfig}"

if [[ -n "${existing_signingkey}" ]]; then
  escaped_key="${existing_signingkey//\//\\/}"
  sed -i "s|signingkey = YOUR_SIGNING_KEY|signingkey = ${escaped_key}|" "${tmp_gitconfig}"
fi

mv "${tmp_gitconfig}" "${local_gitconfig}"
w_log_info "git module installed."
