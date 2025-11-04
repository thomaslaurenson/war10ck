#!/bin/bash

curl -L -o /tmp/mpqeditor.zip http://www.zezula.net/download/mpqeditor_en.zip
unzip -j /tmp/mpqeditor.zip x64/MPQEditor.exe -d /tmp

sudo mkdir -p /opt/mpqeditor
sudo mv /tmp/MPQEditor.exe /opt/mpqeditor/MPQEditor.exe
sudo chmod +x /opt/mpqeditor/MPQEditor.exe

mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/mpqeditor.desktop" <<EOF
[Desktop Entry]
Name=MPQ Editor
Exec=wine "/opt/mpqeditor/MPQEditor.exe"
Type=Application
StartupNotify=true
Icon=wine
Categories=Utility;
EOF

rm -f /tmp/mpqeditor.zip
