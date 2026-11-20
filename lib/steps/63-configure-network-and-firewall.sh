#!/bin/sh -e

. ./lib/steps/common.sh

# The Wi-Fi config holds a password, so it is written with mode 0600.
if [ "${WIFI}" = yes ]; then
    render device/image/templates/network/wpa_supplicant-wlan0.conf.in "${CHROOT}"/etc/wpa_supplicant/wpa_supplicant-wlan0.conf WIFI_COUNTRY WIFI_SSID WIFI_PASSWORD
    chmod 0600 "${CHROOT}"/etc/wpa_supplicant/wpa_supplicant-wlan0.conf
fi
mkdir -p "${CHROOT}"/etc/systemd/network
cp device/image/overlay/network/wlan0.network "${CHROOT}"/etc/systemd/network
# Only the modes with an Ethernet interface get a usb0 network file.
case "${USB_GADGET}:${USB_GADGET_MODE}" in
    yes:rndis|yes:ecm|yes:cdc-ecm|yes:acm-ecm)
        render device/image/templates/network/usb0.network.in "${CHROOT}"/etc/systemd/network/usb0.network USB_ADDRESS
        ;;
esac
# resolv.conf points at the systemd-resolved stub.
ln -sf ../run/systemd/resolve/stub-resolv.conf "${CHROOT}"/etc/resolv.conf
if [ -n "${DNS_SERVER}" ]; then
    mkdir -p "${CHROOT}"/etc/systemd/resolved.conf.d
    printf '[Resolve]\nDNS=%s\n' "${DNS_SERVER}" > "${CHROOT}"/etc/systemd/resolved.conf.d/dns.conf
fi

# SSH_PORT is inserted into the rules. Extra rules go before COMMIT.
mkdir -p "${CHROOT}"/etc/iptables
# Prints the rules file $2 with the extra rules $1 inserted before COMMIT.
add_extra() {
    EXTRA="$1" awk '/^COMMIT$/ && ENVIRON["EXTRA"] != "" {print ENVIRON["EXTRA"]} {print}' "$2"
}
add_extra "${FIREWALL_RULES_V4_EXTRA}" device/image/templates/firewall/rules.v4 | sed "s/@SSH_PORT@/${SSH_PORT}/g" > "${CHROOT}"/etc/iptables/rules.v4
add_extra "${FIREWALL_RULES_V6_EXTRA}" device/image/templates/firewall/rules.v6 > "${CHROOT}"/etc/iptables/rules.v6
# The rules are tested when the host allows netfilter access. Otherwise the test is skipped with a warning.
if ! out=$(iptables-restore --test < "${CHROOT}"/etc/iptables/rules.v4 2>&1); then
    case "${out}" in
        *"Failed to initialize"*|*"Permission denied"*|*"must be root"*) echo "WARNING: firewall rules not checked: no netfilter access here" ;;
        *) echo "${out}"; exit 1 ;;
    esac
fi
