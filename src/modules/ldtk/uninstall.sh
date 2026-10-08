#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Removed first, while the server it points at still exists. A failed remove is
# only fine when it says there was no such entry, as in config.sh.
if w_is_installed claude; then
  if _out=$(claude mcp remove --scope user ldtk 2>&1); then
    w_log_info "Removed ldtk MCP server from Claude Code"
  elif [[ "${_out}" != *"No MCP server named"* ]]; then
    w_log_error "Could not remove the ldtk MCP server: ${_out}"
    exit 1
  fi
fi

w_sudo_remove_symlink "/usr/local/bin/ldtk"
w_sudo_remove_file "/usr/local/bin/ldtk-mcp"
w_sudo_remove_dir "/opt/ldtk"
w_remove_file "$HOME/.local/share/applications/ldtk.desktop"

# NOTE: ~/.config/LDtk holds LDtk's settings and recent projects, which war10ck
# did not create, so it is left in place. cargo-web and unzip are left
# installed too, as general-purpose packages other software is likely to need.

w_log_info "ldtk module uninstalled."
w_log_info "Note: ~/.config/LDtk and cargo-web were intentionally preserved."
