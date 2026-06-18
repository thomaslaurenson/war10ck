#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

MPQEDITOR_URL="http://www.zezula.net/download/mpqeditor_en.zip"

_tmpzip=$(mktemp --suffix=-mpqeditor.zip)
curl -fsSL -o "$_tmpzip" "$MPQEDITOR_URL"

# MPQEditor has no published checksum - print SHA256 for manual audit.
w_log_info "MPQ Editor archive SHA256: $(sha256sum "$_tmpzip" | cut -d' ' -f1)"
w_log_info "Verify against: https://www.zezula.net/en/mpq/download.html"

_tmpdir=$(mktemp -d --suffix=-mpqeditor)
w_q unzip -q "$_tmpzip" x64/MPQEditor.exe -d "$_tmpdir"
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

w_log_info "mpqeditor module installed."
