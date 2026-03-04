#!/bin/bash

set -euo pipefail

MPQEDITOR_URL="http://www.zezula.net/download/mpqeditor_en.zip"

_tmpzip=$(mktemp --suffix=-mpqeditor.zip)
curl -fL -o "$_tmpzip" "$MPQEDITOR_URL"

echo "[*] MPQ Editor archive SHA256: $(sha256sum "$_tmpzip" | cut -d' ' -f1)"
echo "[*] Verify this hash against https://www.zezula.net/en/mpq/download.html"

unzip -j "$_tmpzip" x64/MPQEditor.exe -d /tmp
rm -f "$_tmpzip"

sudo mkdir -p /opt/mpqeditor
sudo mv /tmp/MPQEditor.exe /opt/mpqeditor/MPQEditor.exe
sudo chmod +x /opt/mpqeditor/MPQEditor.exe

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
