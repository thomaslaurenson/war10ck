#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Hand every physical interface to NetworkManager, and retire ifupdown.
#
# Debian ships NetworkManager with the ifupdown plugin set to managed=false,
# which makes it refuse any interface named in /etc/network/interfaces. A laptop
# configured that way ends up with nm-applet in the tray and no device to drive,
# so every network change means hand-editing wpa_supplicant.conf.
#
# Wired is taken as well as wireless, because leaving it behind is what costs a
# war10ck host a minute of every boot. The installer writes an "auto" stanza for
# the wired port, so ifup runs dhclient on it unconditionally at boot; with no
# cable in the socket that blocks for the full 60 second DHCP timeout before
# giving up, and leaves the dhclient resident afterwards retrying forever.
# allow-hotplug on its own would fix the stall, but it keeps two network stacks
# on the machine to no end once NetworkManager is already driving wireless.
#
# No SSIDs or credentials live here. Networks are per-host and stay in
# NetworkManager's own store under /etc/NetworkManager/system-connections/,
# which is what keeps this module byte-identical on every machine. Joining one
# stays a manual step, wrapped by the wifi helper deployed into functions.d.

readonly NM_DROPIN="/etc/NetworkManager/conf.d/10-war10ck.conf"

# Overridable so the stanza rewrite can be exercised against a fixture. Editing
# an interfaces file is the one step here that destroys information, so it is
# worth a test, and pointing the test at the host's real file would make the
# result depend on whatever that host happens to run.
readonly INTERFACES="${WAR10CK_INTERFACES:-/etc/network/interfaces}"

# Staged file contents are built here, so a failure part way through leaves
# nothing behind. A per-function mktemp with an rm after it would not: set -e
# takes the shell out from under the rm.
NETWORK_TMPDIR=$(mktemp -d)
readonly NETWORK_TMPDIR
trap 'rm -rf "${NETWORK_TMPDIR}"' EXIT

# Claim physical devices for NetworkManager. Matching on device type rather than
# an interface name is what makes this generic: predictable names such as
# wlp0s20f3 differ between machines, and a name-based match would need a
# per-host template.
#
# Returns 0 if the file was written, 1 if it was already correct.
write_dropin() {
  local _staged="${NETWORK_TMPDIR}/dropin"
  cat > "${_staged}" <<'CONF'
# Managed by war10ck. NetworkManager owns every physical interface on a war10ck
# host, wired and wireless alike. ifupdown is left with nothing to do.

# This section has to stay ahead of the wired one below. Device sections are
# consulted in order and the first to set "managed" decides, so this is what
# stops the type:ethernet match from claiming the veth pairs and bridges Docker
# creates and tearing down container networking. Leaving it to the udev rules
# that normally protect those devices is not enough, because a device section
# outranks them.
[device-war10ck-virtual]
match-device=type:veth,type:bridge,type:tun,interface-name:docker*,interface-name:veth*
managed=0

[device-war10ck-wifi]
match-device=type:wifi
managed=1

[device-war10ck-wired]
match-device=type:ethernet
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

# Drop every physical interface stanza from ifupdown's config, keeping loopback.
#
# The managed=1 drop-in on its own is not enough. While a stanza for a device
# remains, networking.service still acts on that device at boot, starting its
# own wpa_supplicant or dhclient and racing NetworkManager for it.
#
# Loopback stays because ifupdown is not the only thing that reads it and an
# interfaces file with no lo stanza is a surprise to anything that does.
#
# Returns 0 if the file was rewritten, 1 if there was nothing to remove.
strip_managed_stanzas() {
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
    /^[[:space:]]*(auto|allow-hotplug)[[:space:]]+/ {
      if ($2 == "lo") { printf "%s", pending; pending = ""; print; next }
      pending = ""; next
    }
    /^[[:space:]]*iface[[:space:]]+/ {
      if ($2 == "lo") { printf "%s", pending; pending = ""; print; next }
      pending = ""; drop = 1; next
    }
    { printf "%s", pending; pending = ""; print }
    END { printf "%s", pending }
  ' "${INTERFACES}" > "${_staged}"

  if cmp -s "${_staged}" "${INTERFACES}"; then
    return 1
  fi

  sudo install -m 0644 "${_staged}" "${INTERFACES}"
  w_log_info "Removed managed interface stanzas from ${INTERFACES}"
  return 0
}

# Take ifupdown out of the boot path.
#
# Stopping the unit before the stanzas are removed is deliberate: ifdown -a
# releases each lease and reaps the dhclient that goes with it, which a later
# stop cannot do once the stanzas naming those interfaces are gone. A host on
# wired loses the link for the second or two NetworkManager takes to claim the
# device, which is the price of not leaving an orphan dhclient behind until the
# next reboot.
#
# Disabled rather than masked, so a host that needs ifupdown back only has to
# enable it again.
#
# Returns 0 if anything changed, 1 if ifupdown was already out of the way.
retire_ifupdown() {
  local changed=1

  if systemctl is-active --quiet networking.service; then
    w_q sudo systemctl stop networking.service
    w_log_info "Stopped networking.service"
    changed=0
  fi

  if systemctl is-enabled --quiet networking.service 2>/dev/null; then
    w_q sudo systemctl disable networking.service
    w_log_info "Disabled networking.service"
    changed=0
  fi

  return "${changed}"
}

main() {
  local changed=0

  w_deploy_functions network

  if write_dropin; then changed=1; fi
  if retire_ifupdown; then changed=1; fi
  if strip_managed_stanzas; then changed=1; fi

  if (( changed == 0 )); then
    w_log_info "NetworkManager already owns networking; nothing to do."
    return 0
  fi

  w_q sudo systemctl restart NetworkManager
  w_log_info "NetworkManager now owns wired and wireless."
  w_log_info "Join a network from a new shell with the wifi helper, or with nmcli directly."
}

main "$@"
