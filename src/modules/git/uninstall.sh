#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_remove_functions git
w_remove_file "$HOME/.war10ck/git/gitconfig"
w_remove_file "$HOME/.war10ck/git/both-hosts.gitconfig"
w_remove_file "$HOME/.war10ck/git/no-identity.gitconfig"
w_remove_block "$HOME/.gitconfig" '^# war10ck BEGIN git$' '^# war10ck END git$'

w_apt_remove git

# NOTE: ~/.gitconfig and the host identities in ~/.war10ck/git
# (github.gitconfig, bitbucket.gitconfig) are NOT removed. They carry the
# user's names, emails, and signing keys, which are theirs rather than
# war10ck's to discard.

w_log_info "git module uninstalled."
w_log_info "Note: ~/.gitconfig and the host identities in ~/.war10ck/git were intentionally preserved."
