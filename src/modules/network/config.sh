#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Hand wireless, and only wireless, to NetworkManager.
#
# Debian ships NetworkManager with the ifupdown plugin set to managed=false,
# which makes it refuse any interface named in /etc/network/interfaces. A laptop
# configured that way ends up with nm-applet in the tray and no device to drive,
# so every network change means hand-editing wpa_supplicant.conf.
#
# Wired interfaces are deliberately left to ifupdown. Taking those as well would
# be tidier, but applying this module would then drop an active wired connection
# part way through, which is not a reasonable thing for a config run to do.
#
# No SSIDs or credentials live here. Networks are per-host and stay in
# NetworkManager's own store under /etc/NetworkManager/system-connections/,
# which is what keeps this module byte-identical on every machine. Joining one
# stays a manual step, wrapped by the wifi helper deployed into functions.d.

readonly NM_DROPIN="/etc/NetworkManager/conf.d/10-war10ck.conf"
readonly INTERFACES="/etc/network/interfaces"

# Staged file contents are built here, so a failure part way through leaves
# nothing behind. A per-function mktemp with an rm after it would not: set -e
# takes the shell out from under the rm.
NETWORK_TMPDIR=$(mktemp -d)
readonly NETWORK_TMPDIR
trap 'rm -rf "${NETWORK_TMPDIR}"' EXIT

# Claim wireless devices for NetworkManager. Matching on device type rather than
# an interface name is what makes this generic: predictable names such as
# wlp0s20f3 differ between machines, and a name-based match would need a
# per-host template.
#
# Returns 0 if the file was written, 1 if it was already correct.
write_dropin() {
  local _staged="${NETWORK_TMPDIR}/dropin"
  cat > "${_staged}" <<'CONF'
# Managed by war10ck. NetworkManager owns wireless on every war10ck host.
# Wired interfaces are left to ifupdown, so /etc/network/interfaces still
# applies to them.
[device-war10ck-wifi]
match-device=type:wifi
managed=1
CONF

  if [[ -f "${NM_DROPIN}" ]] && cmp -s "${_staged}" "${NM_DROPIN}"; then
    return 1
  fi

  w_sudo_mkdir "$(dirname "${NM_DROPIN}")"
  sudo install -m 0644 "${_staged}" "${NM_DROPIN}"
  w_log_info "Deployed: ${NM_DROPIN}"
  return 0
}

# Drop the wireless stanzas from ifupdown's config, leaving wired ones alone.
#
# The managed=1 drop-in on its own is not enough. While an "iface wl... wpa-conf"
# stanza remains, networking.service still starts its own wpa_supplicant on that
# interface at boot and races NetworkManager for the device.
#
# Returns 0 if the file was rewritten, 1 if there was nothing to remove.
strip_wireless_stanzas() {
  [[ -f "${INTERFACES}" ]] || return 1

  local _staged="${NETWORK_TMPDIR}/interfaces"
  awk '
    # An indented line continues the stanza opened above it, so it inherits that
    # stanza fate. Matched before drop is reset, which is why the reset below
    # only ever applies to lines that start a new stanza.
    /^[[:space:]]/ { if (!drop) print; next }
    { drop = 0 }
    # Comments are held rather than printed, because a comment sitting directly
    # above a stanza is that stanza heading and should leave with it. Anything
    # else, including a blank line, flushes them back out in order.
    /^[[:space:]]*#/ { pending = pending $0 "\n"; next }
    /^[[:space:]]*(auto|allow-hotplug)[[:space:]]+wl/ { pending = ""; next }
    /^[[:space:]]*iface[[:space:]]+wl/ { pending = ""; drop = 1; next }
    { printf "%s", pending; pending = ""; print }
    END { printf "%s", pending }
  ' "${INTERFACES}" > "${_staged}"

  if cmp -s "${_staged}" "${INTERFACES}"; then
    return 1
  fi

  sudo install -m 0644 "${_staged}" "${INTERFACES}"
  w_log_info "Removed wireless stanzas from ${INTERFACES}"
  return 0
}

main() {
  local changed=0

  w_deploy_functions network

  if write_dropin; then changed=1; fi
  if strip_wireless_stanzas; then changed=1; fi

  if (( changed == 0 )); then
    w_log_info "Wireless already belongs to NetworkManager; nothing to do."
    return 0
  fi

  w_q sudo systemctl restart NetworkManager
  w_log_info "NetworkManager now owns wireless."
  w_log_info "Join a network from a new shell with the wifi helper, or with nmcli directly."
}

main "$@"
