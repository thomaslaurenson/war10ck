#!/usr/bin/env bash
# Runtime display controller - runs on i3 init and every exec_always reload.
# Handles physical monitor topology and polybar. Workspaces follow the
# workspace-to-output assignments in the host template, which i3 applies
# itself whenever an output appears or disappears.

set -euo pipefail

readonly INTERNAL="eDP-1"

# awk rather than a grep pipeline: no external is an ordinary result here, and
# a grep that matches nothing would fail the pipeline under pipefail.
external=$(xrandr --query |
  awk -v internal="${INTERNAL}" '$2 == "connected" && $1 != internal {print $1; exit}')

# One xrandr call naming every output the driver reports. An output left out of
# the call keeps the CRTC it already had, so outputs that are no longer in use
# are named with --off rather than skipped.
xrandr_args=()
if [[ -n "${external}" ]]; then
  # External monitor sits to the left of the laptop screen. Both outputs are
  # placed explicitly: --auto sets a mode and leaves the position alone, so an
  # output not given one keeps where it sat in the previous arrangement.
  xrandr_args+=(--output "${external}" --auto --pos 0x0)
  xrandr_args+=(--output "${INTERNAL}" --auto --primary --right-of "${external}")
else
  xrandr_args+=(--output "${INTERNAL}" --auto --primary --pos 0x0)
fi

while IFS= read -r output; do
  if [[ "${output}" != "${INTERNAL}" && "${output}" != "${external}" ]]; then
    xrandr_args+=(--output "${output}" --off)
  fi
done < <(xrandr --query | awk '$2 == "connected" || $2 == "disconnected" {print $1}')

xrandr "${xrandr_args[@]}"

# Wait for the outputs just asked for before polybar attaches bars to them.
# --listmonitors lists an output once it holds a CRTC, so it reports readiness
# rather than a guess at how long the switch takes.
expected=("${INTERNAL}")
if [[ -n "${external}" ]]; then
  expected+=("${external}")
fi

for ((attempt = 0; attempt < 20; attempt++)); do
  active=$(xrandr --listmonitors | awk 'NR > 1 {print $NF}')
  ready=1
  for output in "${expected[@]}"; do
    if ! grep -qx -- "${output}" <<< "${active}"; then
      ready=0
    fi
  done
  if [[ "${ready}" -eq 1 ]]; then
    break
  fi
  sleep 0.1
done

# The bars belong to the polybar module, which may not be applied on this host.
readonly POLYBAR_LAUNCH="${HOME}/.war10ck/polybar/launch.sh"
if [[ -x "${POLYBAR_LAUNCH}" ]]; then
  "${POLYBAR_LAUNCH}"
else
  printf 'display-setup: no polybar launcher at %s\n' "${POLYBAR_LAUNCH}" >&2
fi
