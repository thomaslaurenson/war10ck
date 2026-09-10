# function: w_wifi
#
# Wrapper around the handful of nmcli invocations worth remembering. The network
# module hands wireless to NetworkManager but deliberately stores no SSIDs, so
# joining a network stays a per-host manual step, and this is that step.
w_wifi() {
  local action=${1:-status}
  (( $# > 0 )) && shift

  case "${action}" in
    --help|-h|help)
      printf '%s\n' \
        'Usage: w_wifi [COMMAND] [ARGS]' \
        '' \
        'Join and manage wireless networks through NetworkManager.' \
        '' \
        'Commands:' \
        '  status                Show the wireless devices and what they are on' \
        '  list                  Scan for nearby networks' \
        '  saved                 List saved wireless connections' \
        '  join SSID [--hidden]  Join a network, prompting for the passphrase' \
        '  forget SSID           Delete a saved connection' \
        '' \
        'With no command, status is shown.' \
        '' \
        'Examples:' \
        '  w_wifi list' \
        '  w_wifi join "Coffee Shop"' \
        '  w_wifi join HomeNet --hidden' \
        '  w_wifi forget HomeNet'
      return 0
      ;;
  esac

  if ! command -v nmcli > /dev/null 2>&1; then
    printf 'w_wifi: nmcli not found, apply the war10ck network module first\n' >&2
    return 1
  fi

  # The name a network carries can contain spaces, so every awk filter below
  # reads a fixed-width field ahead of it rather than the name itself.
  case "${action}" in
    status)
      # The exact match drops wifi-p2p, which is a second entry for the same
      # radio and never holds the connection being asked about.
      nmcli -f TYPE,STATE,DEVICE,CONNECTION device status |
        awk 'NR == 1 || $1 == "wifi"'
      ;;
    list)
      # --rescan yes forces a fresh scan. Without it nmcli prints a cached list
      # that can be minutes old, so a network switched on a moment ago is absent
      # from it, which reads as the network being broken.
      nmcli device wifi list --rescan yes
      ;;
    saved)
      nmcli -f TYPE,AUTOCONNECT,NAME connection show |
        awk 'NR == 1 || $1 == "wifi"'
      ;;
    join)
      local ssid="" hidden="no"
      while (( $# > 0 )); do
        case "$1" in
          --hidden) hidden="yes" ;;
          -*) printf 'w_wifi: unknown option: %s\n' "$1" >&2; return 1 ;;
          *) ssid=$1 ;;
        esac
        shift
      done

      if [[ -z "${ssid}" ]]; then
        printf 'w_wifi: join needs an SSID, run "w_wifi list" to see them\n' >&2
        return 1
      fi

      # --ask makes nmcli prompt for the passphrase on the terminal. Giving it
      # as "password <secret>" instead would put the secret in the shell history
      # and in the process list, where every user on the machine can read it.
      # An open network prompts for nothing, and a network already saved
      # reconnects from the stored secret.
      nmcli --ask device wifi connect "${ssid}" hidden "${hidden}"
      ;;
    forget)
      local ssid=${1:-}
      if [[ -z "${ssid}" ]]; then
        printf 'w_wifi: forget needs an SSID, run "w_wifi saved" to see them\n' >&2
        return 1
      fi
      nmcli connection delete id "${ssid}"
      ;;
    *)
      printf 'w_wifi: unknown command: %s, run "w_wifi --help"\n' "${action}" >&2
      return 1
      ;;
  esac
}
