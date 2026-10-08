#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

readonly ASEPRITE_DIR="/opt/aseprite"
readonly ASEPRITE_MCP_DIR="${HOME}/.local/share/aseprite-mcp"

if [[ ! -x "${ASEPRITE_DIR}/aseprite" || ! -d "${ASEPRITE_MCP_DIR}" ]]; then
  w_log_error "Aseprite installation not found. Run 'war10ck install aseprite' first."
  exit 1
fi

if ! w_is_installed claude; then
  w_log_error "claude not found. Install it with: war10ck install claude"
  exit 1
fi

_uv=$(command -v uv) || {
  w_log_error "uv not found. Install it with: war10ck install uv"
  exit 1
}

# Written here rather than taken from the source tree's aseprite.desktop, which
# names its icon "aseprite" and so needs one installed into an icon theme.
_mime="image/x-aseprite;image/png;image/gif;image/jpeg;image/bmp;image/webp;"
_mime+="image/x-pcx;image/x-tga;"

mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/aseprite.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Aseprite
GenericName=Sprite Editor
Comment=Animated sprite editor and pixel art tool
Exec=${ASEPRITE_DIR}/aseprite %U
Icon=${ASEPRITE_DIR}/data/icons/ase256.png
Terminal=false
StartupNotify=false
StartupWMClass=Aseprite
Categories=Graphics;2DGraphics;RasterGraphics;
MimeType=${_mime}
EOF

# claude mcp add refuses a name that already exists, so a re-run removes the
# old entry first. A failed remove is only fine when it says there was no such
# entry: anything else is a real error, and treating it as "nothing to remove"
# would let the add below fail with a less useful message.
if ! _out=$(claude mcp remove --scope user aseprite 2>&1); then
  if [[ "${_out}" != *"No MCP server named"* ]]; then
    w_log_error "Could not remove the existing aseprite MCP server: ${_out}"
    exit 1
  fi
fi

# User scope, so the server is available in every project. uv is recorded by
# absolute path because Claude Code spawns the server with its own PATH, which
# need not include ~/.local/bin. --no-dev matches the install's sync: uv run
# otherwise installs the dev group on first launch.
w_q claude mcp add --scope user aseprite \
  --env "ASEPRITE_PATH=${ASEPRITE_DIR}/aseprite" \
  -- "${_uv}" --directory "${ASEPRITE_MCP_DIR}" run --frozen --no-dev -m aseprite_mcp

w_log_info "aseprite config installed."
