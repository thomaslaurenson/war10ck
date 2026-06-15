#!/bin/bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# In normal mode all noisy commands are silenced; debug mode streams full output.
_q() { if [[ "${WAR10CK_DEBUG:-0}" == "1" ]]; then "$@"; else "$@" >/dev/null 2>&1; fi; }

if [[ "${WAR10CK_LOCAL:-0}" == "1" ]]; then
    _fetch() { cp "$2" "$1"; }
elif command -v curl &>/dev/null; then
    _fetch() { curl -fsSL -o "$1" "$2"; }
elif command -v wget &>/dev/null; then
    _fetch() { wget -q -O "$1" "$2"; }
else
    echo "[!] No fetch command found. Exiting."
    exit 1
fi

POLYBAR_DIR="$HOME/.war10ck/polybar"
mkdir -p "$POLYBAR_DIR"

echo "[*] Configuring polybar..."
_fetch "$POLYBAR_DIR/config.ini" "$BASE_URL/modules/polybar/config.ini"
_fetch "$POLYBAR_DIR/launch.sh"  "$BASE_URL/modules/polybar/launch.sh"
chmod +x "$POLYBAR_DIR/launch.sh"

echo "[*] Polybar config installed to $POLYBAR_DIR"
