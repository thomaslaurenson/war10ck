#!/bin/bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# In normal mode all noisy commands are silenced; debug mode streams full output.
_q() { if [[ "${WAR10CK_DEBUG:-0}" == "1" ]]; then "$@"; else "$@" >/dev/null 2>&1; fi; }

MPQEDITOR_URL="http://www.zezula.net/download/mpqeditor_en.zip"

_tmpzip=$(mktemp --suffix=-mpqeditor.zip)
curl -fsSL -o "$_tmpzip" "$MPQEDITOR_URL"

# MPQEditor has no published checksum — print SHA256 for manual audit.
echo "[*] MPQ Editor archive SHA256: $(sha256sum "$_tmpzip" | cut -d' ' -f1)"
echo "[*] Verify against: https://www.zezula.net/en/mpq/download.html"

_tmpdir=$(mktemp -d --suffix=-mpqeditor)
_q unzip -q "$_tmpzip" x64/MPQEditor.exe -d "$_tmpdir"
rm -f "$_tmpzip"

sudo mkdir -p /opt/mpqeditor
sudo mv "$_tmpdir/x64/MPQEditor.exe" /opt/mpqeditor/MPQEditor.exe
sudo chmod +x /opt/mpqeditor/MPQEditor.exe
rm -rf "$_tmpdir"

mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/mpqeditor.desktop" <<EOF
[Desktop Entry]
Name=MPQ Editor
Exec=wine "/opt/mpqeditor/MPQEditor.exe" %U
Type=Application
StartupNotify=true
Icon=wine
Categories=Utility;GTK;
MimeType=application/octet-stream;
EOF
