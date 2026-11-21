#!/bin/sh -e

# Write a random locally administered MAC address for wlan0, once per device.
# The unit only runs while the MAC file is missing.
MAC_FILE=/usr/lib/firmware/wcnss_mac_addr
LINK_FILE=/etc/systemd/network/10-wlan0.link

MAC=$(od -An -N6 -tu1 /dev/urandom | awk '{ printf "%02X", ($1 - $1 % 4) + 2; for (i = 2; i <= 6; i++) printf ":%02X", $i }')
printf '%s' "${MAC}" > "${MAC_FILE}"

mkdir -p "$(dirname "${LINK_FILE}")"
printf '[Match]\nOriginalName=wlan0\n\n[Link]\nMACAddress=%s\n' "${MAC}" > "${LINK_FILE}"

# apply now when wlan0 exists; the link file applies at every later boot
if [ -e /sys/class/net/wlan0 ]; then
    ip link set dev wlan0 down
    ip link set dev wlan0 address "${MAC}"
    ip link set dev wlan0 up
fi
