#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Removes only this module's file from env.d, never the directory itself,
# which other modules share.
w_remove_file "$HOME/.war10ck/env.d/emsdk"

# ~/.local/share/emsdk holds the checkout, the SDK and Node it downloaded, the
# .emscripten config and the compiler cache. The install created it, so the
# uninstall removes it.
w_remove_dir "$HOME/.local/share/emsdk"

# NOTE: git, python3, xz-utils and ca-certificates are left installed, as
# general-purpose packages other software is likely to need.

w_log_info "emsdk module uninstalled."
w_log_info "Note: restart your shell to clear emsdk from the current session."
