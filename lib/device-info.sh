
# Writes NAME=value lines that a shell can read. Single quotes in the value are escaped.
put() {
    printf "%s='%s'\n" "$1" "$(printf '%s' "$2" | sed "s/'/'\\\\''/g")"
}
# Records the build details for the user. The file holds passwords, so only its owner can read it.
write_device_info() {
(
    umask 077
    {
        echo "# Device details from this build. Holds passwords: keep this file private."
        put HOST_NAME "${HOST_NAME}"
        put ADMIN_USER "${ADMIN_USER}"
        put ADMIN_PASSWORD "${ADMIN_PASSWORD}"
        put MACHINE_ID "${MACHINE_ID:-generated on first boot}"
        put WIFI_SSID "${WIFI_SSID}"
        put WIFI_PASSWORD "${WIFI_PASSWORD}"
        put WIFI_COUNTRY "${WIFI_COUNTRY}"
        put WIFI_MAC "${WIFI_MAC:-generated on first boot}"
        put DNS_SERVER "${DNS_SERVER}"
        put USB_ADDRESS "${USB_ADDRESS}"
        put SSH_PORT "${SSH_PORT}"
        put SSH_ALLOW_FROM "${SSH_ALLOW_FROM}"
        put BOARD "${BOARD}"
        put ROOT_PARTUUID "${ROOT_PARTUUID}"
        put BOOT_PARTUUID "${BOOT_PARTUUID}"
        put BUILD_DATE "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        put RELEASE "${RELEASE}"
        put DEBIAN_MIRROR "${DEBIAN_MIRROR}"
        put TIMEZONE "${TIMEZONE}"
        put LOCALE "${LOCALE}"
        put SSH_GROUP "${SSH_GROUP}"
        put WHEEL_GROUP "${WHEEL_GROUP}"
        put NTP_SERVERS "${NTP_SERVERS}"
        put UPGRADE_TIME "${UPGRADE_TIME}"
        put UPGRADE_DELAY "${UPGRADE_DELAY}"
        put SECURITY_SUITE "${SECURITY_SUITE}"
        put BOARD_COMPATIBLE "${BOARD_COMPATIBLE}"
        put BOOT_ARGS "${BOOT_ARGS}"
    } > work/files/device-info.env
)
msg OK "device details written to work/files/device-info.env"
}
