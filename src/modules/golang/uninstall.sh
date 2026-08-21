#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_sudo_remove_symlink "/usr/local/bin/go"
w_sudo_remove_symlink "/usr/local/bin/gofmt"
w_sudo_remove_dir "/usr/local/go"

w_sudo_remove_file "/usr/local/bin/goreleaser"
w_sudo_remove_file "/usr/local/bin/govulncheck"

# Removes only this module's file from env.d, never the directory itself,
# which other modules share.
w_remove_file "$HOME/.war10ck/env.d/golang"

# NOTE: $GOPATH (~/go by default) holds downloaded modules and user source,
# so it is left in place.

w_log_info "golang module uninstalled."
w_log_info "Note: ~/go (GOPATH) was intentionally preserved."
