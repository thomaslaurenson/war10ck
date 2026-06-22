#!/usr/bin/env bash
# Compiler script - run once during dotfiles sync.
# Detects hostname and concatenates base + host template into final i3 config.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$SCRIPT_DIR/templates"
OUTPUT="$SCRIPT_DIR/config"

HOST=$(hostname)

if [ -f "$TEMPLATES/config.$HOST" ]; then
    cat "$TEMPLATES/config.base" "$TEMPLATES/config.$HOST" > "$OUTPUT"
    chmod 644 "$OUTPUT"
    echo "bundle.sh: compiled config for host '$HOST' -> $OUTPUT"
else
    echo "bundle.sh: no template found for host '$HOST' (expected $TEMPLATES/config.$HOST)" >&2
    exit 1
fi
