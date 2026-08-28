#!/usr/bin/env bash
# Runtime display controller - runs on i3 init and every exec_always reload.
# Handles physical monitor topology and polybar. Workspaces follow the
# workspace-to-output assignments in the host template, which i3 applies
# itself whenever an output appears or disappears.

INTERNAL="eDP-1"
EXTERNAL=$(xrandr | grep " connected" | grep -v "$INTERNAL" | awk '{print $1}' | head -n 1)

# One xrandr call naming every output the driver reports. An output left out of
# the call keeps the CRTC it already had, so outputs that are no longer in use
# are named with --off rather than skipped.
XRANDR_ARGS=()
if [ -n "$EXTERNAL" ]; then
    # External monitor sits to the left of the laptop screen. Both outputs are
    # placed explicitly: --auto sets a mode and leaves the position alone, so an
    # output not given one keeps where it sat in the previous arrangement.
    XRANDR_ARGS+=(--output "$EXTERNAL" --auto --pos 0x0)
    XRANDR_ARGS+=(--output "$INTERNAL" --auto --primary --right-of "$EXTERNAL")
else
    XRANDR_ARGS+=(--output "$INTERNAL" --auto --primary --pos 0x0)
fi

while IFS= read -r output; do
    if [ "$output" != "$INTERNAL" ] && [ "$output" != "$EXTERNAL" ]; then
        XRANDR_ARGS+=(--output "$output" --off)
    fi
done < <(xrandr --query | awk '$2 == "connected" || $2 == "disconnected" {print $1}')

xrandr "${XRANDR_ARGS[@]}"

# Give xrandr a moment to settle before polybar attaches to outputs.
sleep 0.5

# The bars belong to the polybar module, which may not be applied on this host.
POLYBAR_LAUNCH="$HOME/.war10ck/polybar/launch.sh"
if [ -x "$POLYBAR_LAUNCH" ]; then
    "$POLYBAR_LAUNCH"
else
    printf 'display-setup: no polybar launcher at %s\n' "$POLYBAR_LAUNCH" >&2
fi
