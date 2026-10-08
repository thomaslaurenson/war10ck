#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

readonly LDTK_DIR="/opt/ldtk"
readonly LDTK_MCP_BIN="/usr/local/bin/ldtk-mcp"

if [[ ! -x "${LDTK_DIR}/ldtk" || ! -x "${LDTK_MCP_BIN}" ]]; then
  w_log_error "LDtk installation not found. Run 'war10ck install ldtk' first."
  exit 1
fi

if ! w_is_installed claude; then
  w_log_error "claude not found. Install it with: war10ck install claude"
  exit 1
fi

# Written here rather than taken from the AppImage's ldtk.desktop, which claims
# application/json and so would offer LDtk for every JSON file. It also
# launches with --no-sandbox, which only the AppImage needs: a FUSE mount
# cannot hold the setuid sandbox helper. Unpacked, Electron falls back to the
# user namespace sandbox instead, so the flag would only switch it off.
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/ldtk.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=LDtk
GenericName=Level Editor
Comment=2D level editor
Exec=${LDTK_DIR}/ldtk %U
Icon=${LDTK_DIR}/ldtk.png
Terminal=false
StartupWMClass=LDtk
Categories=Development;Graphics;2DGraphics;
EOF

# claude mcp add refuses a name that already exists, so a re-run removes the
# old entry first. A failed remove is only fine when it says there was no such
# entry, as in the aseprite module.
if ! _out=$(claude mcp remove --scope user ldtk 2>&1); then
  if [[ "${_out}" != *"No MCP server named"* ]]; then
    w_log_error "Could not remove the existing ldtk MCP server: ${_out}"
    exit 1
  fi
fi

# User scope, so the server is available in every project.
w_q claude mcp add --scope user ldtk -- "${LDTK_MCP_BIN}"

w_log_info "ldtk config installed."
