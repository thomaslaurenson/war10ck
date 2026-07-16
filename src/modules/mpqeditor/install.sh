#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# zezula.net serves no working HTTPS (its cert covers an unrelated domain), so
# this is fetched over plain http. The pinned SHA256 below is what actually
# guards against tampering in transit - update it whenever the archive changes
# by re-downloading and running sha256sum.
readonly MPQEDITOR_URL="http://www.zezula.net/download/mpqeditor_en.zip"
readonly MPQEDITOR_SHA256="ec609a60bf453544c754e2a5a3be29be09b292354ce4bc8c30e2c4abbc27947e"

_tmpzip=$(mktemp --suffix=-mpqeditor.zip)
w_download "${MPQEDITOR_URL}" "${_tmpzip}"

if ! w_verify_sha256 "${_tmpzip}" "${MPQEDITOR_SHA256}"; then
  rm -f "${_tmpzip}"
  exit 1
fi

_tmpdir=$(mktemp -d --suffix=-mpqeditor)
w_q unzip -q "${_tmpzip}" x64/MPQEditor.exe -d "${_tmpdir}"
rm -f "${_tmpzip}"

w_sudo_mkdir /opt/mpqeditor
sudo mv "${_tmpdir}/x64/MPQEditor.exe" /opt/mpqeditor/MPQEditor.exe
w_sudo_make_executable /opt/mpqeditor/MPQEditor.exe
rm -rf "${_tmpdir}"

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
