#!/usr/bin/env bash
# Runtime display controller - runs on i3 init and every exec_always reload.
# Handles physical monitor topology only. Workspace-to-output assignments are
# static in the host config template and managed natively by i3.

INTERNAL="eDP-1"
EXTERNAL=$(xrandr | grep " connected" | grep -v "$INTERNAL" | awk '{print $1}' | head -n 1)

# Returns "true" if a workspace has no open windows.
ws_is_empty() {
    local ws_name="$1"
    i3-msg -t get_tree | python3 -c "
import json, sys
def find_ws(node, name):
    if node.get('type') == 'workspace' and node.get('name') == name:
        return node
    for child in node.get('nodes', []) + node.get('floating_nodes', []):
        result = find_ws(child, name)
        if result:
            return result
    return None
tree = json.load(sys.stdin)
ws = find_ws(tree, '$ws_name')
has_windows = bool(ws and (ws.get('nodes') or ws.get('floating_nodes')))
print('false' if has_windows else 'true')
"
}

if [ -n "$EXTERNAL" ]; then
    # --- DOCKED MODE ---
    # Position external as primary, internal to the left.
    xrandr --output "$EXTERNAL" --auto --primary --output "$INTERNAL" --auto --left-of "$EXTERNAL"

    # Apply WS2 split layout only on first dock (not on every reload).
    if [ "$(ws_is_empty '2')" = "true" ]; then
        i3-msg "workspace 2; append_layout ~/.war10ck/i3/layouts/docked_ws2.json"
    fi
else
    # --- LAPTOP ONLY MODE ---
    xrandr --output "$INTERNAL" --auto --primary
fi
