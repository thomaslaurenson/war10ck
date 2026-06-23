#!/usr/bin/env bash
# Runtime display controller - runs on i3 init and every exec_always reload.
# Handles physical monitor topology, workspace-to-output migration, and polybar.

INTERNAL="eDP-1"
EXTERNAL=$(xrandr | grep " connected" | grep -v "$INTERNAL" | awk '{print $1}' | head -n 1)

if [ -n "$EXTERNAL" ]; then
    # DOCKED MODE
    # External monitor sits to the left of the laptop screen.
    xrandr --output "$EXTERNAL" --auto --left-of "$INTERNAL" --output "$INTERNAL" --auto --primary

    # Pin WS 1-3 to laptop, WS 4-6 to external.
    # Explicit moves handle the case where workspaces were on the wrong output
    # (e.g. after a config change or first dock after being laptop-only).
    i3-msg "workspace 1; move workspace to output $INTERNAL" > /dev/null 2>&1
    i3-msg "workspace 2; move workspace to output $INTERNAL" > /dev/null 2>&1
    i3-msg "workspace 3; move workspace to output $INTERNAL" > /dev/null 2>&1
    i3-msg "workspace 4; move workspace to output $EXTERNAL" > /dev/null 2>&1
    i3-msg "workspace 5; move workspace to output $EXTERNAL" > /dev/null 2>&1
    i3-msg "workspace 6; move workspace to output $EXTERNAL" > /dev/null 2>&1
    i3-msg "workspace 1" > /dev/null 2>&1
else
    # LAPTOP ONLY MODE
    xrandr --output "$INTERNAL" --auto --primary
fi

# Launch polybar after xrandr has finished configuring all monitors.
# Polybar must start after this point so it can attach to both outputs.
~/.war10ck/polybar/launch.sh
