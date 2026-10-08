#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Removed first, while the server it points at still exists. A failed remove is
# only fine when it says there was no such entry, as in config.sh.
if w_is_installed claude; then
  if _out=$(claude mcp remove --scope user aseprite 2>&1); then
    w_log_info "Removed aseprite MCP server from Claude Code"
  elif [[ "${_out}" != *"No MCP server named"* ]]; then
    w_log_error "Could not remove the aseprite MCP server: ${_out}"
    exit 1
  fi
fi

w_sudo_remove_symlink "/usr/local/bin/aseprite"
w_sudo_remove_dir "/opt/aseprite"
w_remove_dir "$HOME/.local/share/aseprite-mcp"
w_remove_file "$HOME/.local/share/applications/aseprite.desktop"

# NOTE: ~/.config/aseprite holds preferences, scripts and extensions, and
# ~/.aseprite-mcp holds fonts for the MCP's text tools. war10ck created neither,
# so both are left in place. The build dependencies are left installed too, as
# general-purpose packages other software is likely to need.

w_log_info "aseprite module uninstalled."
w_log_info "Note: ~/.config/aseprite and the build dependencies were intentionally preserved."
