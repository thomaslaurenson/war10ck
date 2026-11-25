#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_apt_install git

# ~/.gitconfig belongs to the user and is never rewritten: install only appends
# one include of the war10ck settings, which config deploys. Anything else in
# the file, including settings added later with git config --global, survives
# a rerun. Identity lives in one file per host under ~/.war10ck/git, included
# by the war10ck settings according to the host of a repository's remotes.
readonly GITCONFIG="$HOME/.gitconfig"
readonly IDENTITY_DIR="$HOME/.war10ck/git"

# Prompt for a key a config file lacks and write the answer there. An empty
# answer writes nothing.
#
# Arguments:
#   $1 - Config file
#   $2 - Key (e.g. user.name)
#   $3 - Prompt message
#   $4 - Value used for an empty answer, optional
_set_if_missing() {
  local file=$1
  local key=$2
  local message=$3
  local fallback=${4:-}
  local value
  value=$(git config -f "${file}" "${key}" 2>/dev/null || true)
  if [[ -n "${value}" ]]; then
    w_log_info "Using existing ${key} in ${file}: ${value}"
    return 0
  fi
  value=$(w_prompt "${message}")
  value=${value:-${fallback}}
  if [[ -n "${value}" ]]; then
    git config -f "${file}" "${key}" "${value}"
  fi
}

# Prompt for one host's identity. Skipping the email writes no file, so that
# host's repositories have no identity and cannot commit.
#
# Arguments:
#   $1 - File name stem, matching the include in the war10ck settings
#   $2 - Host name shown in the prompts
#   $3 - Name used for an empty answer, optional
_set_host_identity() {
  local stem=$1
  local label=$2
  local name_fallback=${3:-}
  local file="${IDENTITY_DIR}/${stem}.gitconfig"
  local name_prompt="Enter your ${label} Git name"
  if [[ -n "${name_fallback}" ]]; then
    name_prompt+=" (Enter for ${name_fallback})"
  fi

  _set_if_missing "${file}" user.email \
    "Enter your ${label} Git email (or press Enter to skip ${label})"
  [[ -f "${file}" ]] || return 0
  _set_if_missing "${file}" user.name "${name_prompt}" "${name_fallback}"
  _set_if_missing "${file}" user.signingkey \
    "Enter your ${label} Git signing key path"
}

# The include has to follow a [user] section. git config --global, which git's
# own "Author identity unknown" message suggests, adds to an existing [user]
# section but appends a new one at the end of the file when there is none,
# and a section after the include would override every host identity. An empty
# section above the include keeps those keys where the includes override them.
#
# The include is appended rather than written with git config --add, which
# would put it in any [include] section already in the file.
if ! grep -qs '^# war10ck BEGIN git$' "${GITCONFIG}"; then
  grep -qs '^\[user\]' "${GITCONFIG}" || printf '[user]\n' >> "${GITCONFIG}"
  printf '\n# war10ck BEGIN git\n[include]\n\tpath = ~/.war10ck/git/gitconfig\n# war10ck END git\n' \
    >> "${GITCONFIG}"
fi

mkdir -p "${IDENTITY_DIR}"
_set_host_identity github GitHub
_github_name=$(git config -f "${IDENTITY_DIR}/github.gitconfig" user.name \
  2>/dev/null || true)
_set_host_identity bitbucket Bitbucket "${_github_name}"

# An identity in ~/.gitconfig applies wherever no host identity does, so a
# repository with no remote, or on another host, commits with it instead of
# failing. The file is the user's, so this is reported rather than removed.
_defaults=()
for _key in user.name user.email user.signingkey; do
  if git config -f "${GITCONFIG}" "${_key}" > /dev/null 2>&1; then
    _defaults+=("${_key}")
  fi
done
if (( ${#_defaults[@]} > 0 )); then
  w_log_error "${GITCONFIG} sets ${_defaults[*]}, which any repository"
  w_log_error "without a GitHub or Bitbucket remote will use. To remove it:"
  for _key in "${_defaults[@]}"; do
    w_log_error "  git config --global --unset ${_key}"
  done
fi

w_log_info "git module installed."
