#!/usr/bin/env bash
# Runtime display controller - runs on i3 init and every exec_always reload.
# Detects docked vs laptop-only topology and routes workspaces + applications
# without restarting i3 or dropping application state.

INTERNAL="eDP-1"
EXTERNAL=$(xrandr | grep " connected" | grep -v "$INTERNAL" | awk '{print $1}' | head -n 1)

if [ -n "$EXTERNAL" ]; then
    # DOCKED MODE
    xrandr --output "$EXTERNAL" --auto --primary --output "$INTERNAL" --auto --left-of "$EXTERNAL"

    # Workspace output assignments
    i3-msg "workspace 1 output $INTERNAL"
    i3-msg "workspace 2 output $EXTERNAL"
    i3-msg "workspace 3 output $EXTERNAL"

    # Route Firefox to WS2 alongside VS Code
    i3-msg "for_window [class=\"(?i)firefox\"] move to workspace 2"

    # Apply side-by-side split layout for WS2 (VS Code left, Firefox right)
    i3-msg "workspace 2; append_layout ~/.config/i3/layouts/docked_ws2.json"
else
    # LAPTOP ONLY MODE
    xrandr --output "$INTERNAL" --auto --primary

    # All workspaces on internal display
    i3-msg "workspace 1 output $INTERNAL"
    i3-msg "workspace 2 output $INTERNAL"
    i3-msg "workspace 3 output $INTERNAL"

    # Teardown docked Firefox rule; route Firefox back to WS3
    i3-msg "for_window [class=\"(?i)firefox\"] move to workspace 3"
fi
