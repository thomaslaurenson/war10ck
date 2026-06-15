#!/bin/bash


# Get the directory where this script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Kill any existing polybar instances
pkill -x polybar 2>/dev/null || true

# Wait for processes to fully stop
sleep 0.5

# Detect active Wi-Fi interface
WIFI_IFACE=$(ip link show | grep -E '^[0-9]+: wl' | grep 'state UP' | awk -F': ' '{print $2}' | head -n 1)
export WIFI_IFACE
# Fallback for Wi-Fi if none are UP
if [ -z "$WIFI_IFACE" ]; then
    WIFI_IFACE=$(find /sys/class/net -maxdepth 1 -name 'wl*' -printf '%f\n' | head -n 1)
    export WIFI_IFACE
fi

# Detect active Ethernet interface
ETH_IFACE=$(ip link show | grep -E '^[0-9]+: (en|eth)' | grep 'state UP' | awk -F': ' '{print $2}' | head -n 1)
export ETH_IFACE
# Fallback for Ethernet if none are UP
if [ -z "$ETH_IFACE" ]; then
    ETH_IFACE=$(find /sys/class/net -maxdepth 1 \( -name 'en*' -o -name 'eth*' \) -printf '%f\n' | head -n 1)
    export ETH_IFACE
fi

# Launch bar defined in config.ini as [bar/top]
# polybar top -c ~/.war10ck/polybar/config.ini 2>&1 | tee -a /tmp/polybar.log &
polybar top -c "$DIR/config.ini" 2>&1 | tee -a /tmp/polybar.log
disown
