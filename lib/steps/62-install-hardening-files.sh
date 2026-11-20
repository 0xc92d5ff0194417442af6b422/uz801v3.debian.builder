#!/bin/sh -e

. ./lib/steps/common.sh

# Hardening files for sudo, cron, at, profile and sysctl.
cp -a --no-preserve=ownership device/image/overlay/hardening/etc/. "${CHROOT}"/etc/
# The LE9UO sysctl file only works with its kernel patch. A prebuilt kernel has no patches, so the file is removed.
if [ "${PATCH_LE9UO}" != yes ] || [ "${KERNEL_SOURCE}" != build ]; then
    rm -f "${CHROOT}"/etc/sysctl.d/zz-le9uo.conf
fi
# sudo ignores sudoers files that are not mode 0440.
chmod 0440 "${CHROOT}"/etc/sudoers.d/01[1-7]_*
chmod 0600 "${CHROOT}"/etc/cron.allow "${CHROOT}"/etc/at.allow
for f in "${CHROOT}"/etc/profile "${CHROOT}"/etc/bash.bashrc; do
    grep -qx "umask 0077" "${f}" || echo "umask 0077" >> "${f}"
done
cp device/image/overlay/modprobe.d/zz-custom.conf "${CHROOT}"/etc/modprobe.d/

# Blocks each driver with install /bin/false and blacklist. The module then cannot load by any path.
block_modules() {
    for m in "$@"; do
        printf 'install %s /bin/false\nblacklist %s\n' "${m}" "${m}"
    done
}
{
    echo "# blocked because the feature is off in config.env"
    if [ "${BLUETOOTH}" = no ]; then
        block_modules bluetooth bnep btbcm btqca btqcomsmd btusb hci_uart hidp rfcomm net-pf-31
    fi
    if [ "${MODEM}" = no ]; then
        block_modules qcom_bam_dmux qcom_q6v5 qcom_q6v5_mss
    fi
    if [ "${WIFI}" = no ]; then
        block_modules wcn36xx mac80211 cfg80211
    fi
    if [ "${USB_GADGET}" = yes ]; then
        block_modules rndis_host cdc_ether cdc_mbim cdc_ncm usbnet usb-storage usbkbd usbmouse usb-midi
    fi
} >> "${CHROOT}"/etc/modprobe.d/zz-custom.conf

# LOG_LEVEL sets how much the journal keeps. LOG_STORAGE sets where it is kept.
case "${LOG_LEVEL}" in
    full) JOURNAL_MAX_LEVEL=debug ;;
    normal) JOURNAL_MAX_LEVEL=info ;;
    minimal) JOURNAL_MAX_LEVEL=warning ;;
    none) JOURNAL_MAX_LEVEL=emerg ;;
esac
case "${LOG_LEVEL}:${LOG_STORAGE}" in
    none:*|*:none) JOURNAL_STORAGE=none ;;
    *:disk) JOURNAL_STORAGE=persistent ;;
    *:ram) JOURNAL_STORAGE=volatile ;;
esac
export JOURNAL_STORAGE JOURNAL_MAX_LEVEL
mkdir -p "${CHROOT}"/etc/systemd/journald.conf.d
render device/image/templates/logging/journald-logging.conf.in "${CHROOT}"/etc/systemd/journald.conf.d/zz-logging.conf JOURNAL_STORAGE JOURNAL_MAX_LEVEL LOG_MAX_SIZE

if [ "${LOG_SUDO}" = no ]; then
    rm -f "${CHROOT}"/etc/sudoers.d/012_logfile
fi

mkdir -p "${CHROOT}"/etc/systemd/system.conf.d
# Debug logging for systemd. The drop-in is removed when DEBUG_SERVICES is not yes.
if [ "${DEBUG_SERVICES}" = yes ]; then
    printf '[Manager]\nLogLevel=debug\n' > "${CHROOT}"/etc/systemd/system.conf.d/zz-debug.conf
else
    rm -f "${CHROOT}"/etc/systemd/system.conf.d/zz-debug.conf
fi
