#!/bin/sh -e

# Copies the board firmware into the rootfs.
cp -r --no-preserve=ownership device/board/firmware/usr "${CHROOT}"/

# A fixed MAC is written two ways: a systemd link file sets it, and the MAC file stops the first-boot MAC service.
if [ -n "${WIFI_MAC:-}" ]; then
    printf '%s\n' "${WIFI_MAC}" | grep -qE '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$' || { echo "WIFI_MAC must look like AA:BB:CC:DD:EE:FF"; exit 1; }
    MAC=$(printf '%s' "${WIFI_MAC}" | tr 'a-f' 'A-F')
    printf '%s' "${MAC}" > "${CHROOT}"/usr/lib/firmware/wcnss_mac_addr
    mkdir -p "${CHROOT}"/etc/systemd/network
    printf '[Match]\nOriginalName=wlan0\n\n[Link]\nMACAddress=%s\n' "${MAC}" > "${CHROOT}"/etc/systemd/network/10-wlan0.link
fi
