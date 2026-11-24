#!/bin/sh -e

. ./lib/steps/common.sh

# Copies the overlay units. The resize unit is rendered for the chosen root filesystem.
cp -a --no-preserve=ownership device/image/overlay/system/* "${CHROOT}"/etc/systemd/system
# Without Wi-Fi, iw is not installed. The power save unit would fail at each boot and mark the system degraded.
if [ "${WIFI}" = no ]; then
    rm -f "${CHROOT}"/etc/systemd/system/multi-user.target.wants/wifi-powersave-off.service
fi
render device/image/templates/systemd/resize-rootfs.service.in "${CHROOT}"/etc/systemd/system/resize-rootfs.service ROOT_RESIZE_CMD

install -p -m 0755 device/image/overlay/usr/sbin/apt-security-upgrade.sh \
    device/image/overlay/usr/sbin/wcnss-mac-address.sh device/image/overlay/usr/sbin/led-boot.sh "${CHROOT}"/usr/sbin

# systemd reads % as a specifier, so it is doubled for tmp.mount.
TMP_SIZE_OPT=$(printf '%s' "${TMP_SIZE}" | sed 's/%/%%/g')
export TMP_SIZE_OPT
render device/image/templates/systemd/tmp.mount.in "${CHROOT}"/etc/systemd/system/tmp.mount TMP_SIZE_OPT
render device/image/templates/systemd/cpu-governor.service.in "${CHROOT}"/etc/systemd/system/cpu-governor.service CPU_GOVERNOR CPU_MAX_FREQ CPU_ACTIVE_CORES
render device/image/templates/systemd/led-triggers.service.in "${CHROOT}"/etc/systemd/system/led-triggers.service LED_GREEN_TRIGGER LED_BLUE_TRIGGER LED_RED_TRIGGER
render device/image/templates/systemd/apt-security-upgrade.timer.in "${CHROOT}"/etc/systemd/system/apt-security-upgrade.timer UPGRADE_TIME UPGRADE_DELAY

mkdir -p "${CHROOT}"/etc/default
if [ "${ZRAM}" = yes ]; then
    install -p -m 0755 device/image/overlay/usr/sbin/zram-swap.sh "${CHROOT}"/usr/sbin
    printf 'ZRAM_PERCENT=%s\n' "${ZRAM_PERCENT}" > "${CHROOT}"/etc/default/zram-swap
else
    rm -f "${CHROOT}"/etc/systemd/system/zram-swap.service "${CHROOT}"/etc/systemd/system/multi-user.target.wants/zram-swap.service
fi
printf 'SECURITY_SUITE=%s\n' "${SECURITY_SUITE}" > "${CHROOT}"/etc/default/apt-security-upgrade

# The gadget service starts at boot through a multi-user.target symlink.
if [ "${USB_GADGET}" = yes ]; then
    case "${USB_GADGET_MODE}" in
        rndis) GADGET_SCHEME=rndis-os-desc.scheme ;;
        *) GADGET_SCHEME=${USB_GADGET_MODE}.scheme ;;
    esac
    GADGET_NAME=${USB_GADGET_MODE}
    export GADGET_SCHEME GADGET_NAME
    render device/image/templates/gadget/usb-gadget.service.in "${CHROOT}"/etc/systemd/system/usb-gadget.service GADGET_SCHEME GADGET_NAME
    ln -sf /etc/systemd/system/usb-gadget.service "${CHROOT}"/etc/systemd/system/multi-user.target.wants/usb-gadget.service
fi

# The watchdog package is installed by settings.sh. Its config replaces the package default.
if [ "${WATCHDOG}" = yes ]; then
    cp -a --no-preserve=ownership device/image/overlay/watchdog/etc/. "${CHROOT}"/etc/
fi

if [ "${LOG_FORWARD}" = yes ]; then
    LOG_FORWARD_HOST=${LOG_FORWARD_TARGET%:*}
    LOG_FORWARD_PORT=${LOG_FORWARD_TARGET##*:}
    export LOG_FORWARD_HOST LOG_FORWARD_PORT
    render device/image/templates/logging/log-forward.service.in "${CHROOT}"/etc/systemd/system/log-forward.service LOG_FORWARD_HOST LOG_FORWARD_PORT
    ln -sf /etc/systemd/system/log-forward.service "${CHROOT}"/etc/systemd/system/multi-user.target.wants/log-forward.service
fi
