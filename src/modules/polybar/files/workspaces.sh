#!/usr/bin/env bash
# Polybar workspace module - always shows all 6 workspaces.
# Uses i3 IPC subscription for instant updates (no polling delay).

PYTHON_SCRIPT='
import json, sys
data = json.load(sys.stdin)
ws_map = {}
for ws in data:
    if ws.get("focused"):
        ws_map[ws["num"]] = "focused"
    elif ws.get("urgent"):
        ws_map[ws["num"]] = "urgent"
    else:
        ws_map[ws["num"]] = "active"
for i in range(1, 7):
    print(ws_map.get(i, "empty"))
'

print_workspaces() {
    local WORKSPACES OUTPUT="" ws state
    WORKSPACES=$(i3-msg -t get_workspaces 2>/dev/null)

    mapfile -t STATES < <(echo "$WORKSPACES" | python3 -c "$PYTHON_SCRIPT")

    for i in "${!STATES[@]}"; do
        ws=$((i + 1))
        state="${STATES[$i]}"
        case "$state" in
            focused) OUTPUT+="%{F#00FF00}%{u#00FF00}%{+u}%{A1:i3-msg workspace number $ws:}  $ws  %{A}%{-u}%{F-}" ;;
            urgent)  OUTPUT+="%{F#ff0000}%{A1:i3-msg workspace number $ws:}  $ws  %{A}%{F-}" ;;
            active)  OUTPUT+="%{F#f8f8f8}%{A1:i3-msg workspace number $ws:}  $ws  %{A}%{F-}" ;;
            empty)   OUTPUT+="%{F#666666}%{A1:i3-msg workspace number $ws:}  $ws  %{A}%{F-}" ;;
        esac
    done
    echo "$OUTPUT"
}

print_workspaces

# Subscribe to workspace events and refresh on each one
i3-msg -t subscribe '["workspace"]' | while IFS= read -r _; do
    print_workspaces
done
