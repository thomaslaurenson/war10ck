#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

GHIDRA_DIR=$(find /opt -maxdepth 1 -type d -name "ghidra_*_PUBLIC*" | sort | tail -n 1)

if [[ -z "$GHIDRA_DIR" ]]; then
    w_log_error "Ghidra installation not found in /opt. Run 'war10ck install ghidra' first."
    exit 1
fi

w_deploy_remote_file "modules/ghidra/files/env.bash" "$HOME/.war10ck/bashrc.d/ghidra"

mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/ghidra.desktop" <<EOF
[Desktop Entry]
Name=Ghidra
Exec=/usr/local/bin/ghidra
Type=Application
StartupNotify=false
Icon=${GHIDRA_DIR}/support/ghidra-logo-128.png
Categories=Development;Debugger;
EOF

w_log_info "ghidra config installed."
