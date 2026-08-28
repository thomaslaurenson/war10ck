#!/usr/bin/env bash
# Runtime display controller - runs on i3 init and every exec_always reload.
# Handles physical monitor topology, workspace-to-output migration, and polybar.

INTERNAL="eDP-1"
EXTERNAL=$(xrandr | grep " connected" | grep -v "$INTERNAL" | awk '{print $1}' | head -n 1)

# One xrandr call naming every output the driver reports. An output left out of
# the call keeps the CRTC it already had, so outputs that are no longer in use
# are named with --off rather than skipped.
XRANDR_ARGS=()
if [ -n "$EXTERNAL" ]; then
    # External monitor sits to the left of the laptop screen.
    XRANDR_ARGS+=(--output "$EXTERNAL" --auto --left-of "$INTERNAL")
fi
XRANDR_ARGS+=(--output "$INTERNAL" --auto --primary)

while IFS= read -r output; do
    if [ "$output" != "$INTERNAL" ] && [ "$output" != "$EXTERNAL" ]; then
        XRANDR_ARGS+=(--output "$output" --off)
    fi
done < <(xrandr --query | awk '$2 == "connected" || $2 == "disconnected" {print $1}')

xrandr "${XRANDR_ARGS[@]}"

if [ -n "$EXTERNAL" ]; then
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
fi

# Give xrandr a moment to settle before polybar attaches to outputs.
sleep 0.5
~/.war10ck/polybar/launch.sh
