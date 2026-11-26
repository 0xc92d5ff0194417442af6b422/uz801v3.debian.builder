#!/bin/sh -e

. ./lib/steps/common.sh

# A built kernel comes from work/files. A prebuilt kernel is downloaded, and its SHA256 is checked first.
if [ "${KERNEL_SOURCE}" = build ]; then
    mkdir -p "${CHROOT}"/usr/lib/modules
    cp -a --no-preserve=ownership work/files/kernel/rootfs/boot/. "${CHROOT}"/boot/
    cp -a --no-preserve=ownership work/files/kernel/rootfs/lib/modules/. "${CHROOT}"/usr/lib/modules/
else
    KERNEL_TMP=$(mktemp -d)
    trap 'rm -rf "${KERNEL_TMP}"' EXIT
    wget --progress=bar:force -O "${KERNEL_TMP}"/kernel.apk "${KERNEL_APK_URL}" 2>&4
    echo "${KERNEL_SHA256}  ${KERNEL_TMP}/kernel.apk" | sha256sum -c
    tar xkzf "${KERNEL_TMP}"/kernel.apk -C "${CHROOT}" --exclude=.PKGINFO --exclude=.SIGN* --exclude=boot/dtbs
    tar xkzf "${KERNEL_TMP}"/kernel.apk -C "${CHROOT}" boot/dtbs/qcom/"${DTB_NAME}"
fi

mkdir -p "${CHROOT}"/boot/extlinux
# The regulatory domain goes on the kernel command line, so Wi-Fi uses the right channels from boot.
if [ "${WIFI}" = yes ]; then
    BOOT_ARGS="${BOOT_ARGS} cfg80211.ieee80211_regdom=${WIFI_COUNTRY}"
fi
# systemd-gpt-auto-generator cannot find the device behind a btrfs root and fails at every boot.
# The root device is set by PARTUUID, so the generator is not needed here.
if [ "${ROOT_FS}" = btrfs ]; then
    BOOT_ARGS="${BOOT_ARGS} systemd.gpt_auto=0"
    if [ "${BTRFS_COMPRESS}" != none ]; then
        BOOT_ARGS="${BOOT_ARGS} rootflags=compress=${BTRFS_COMPRESS}${BTRFS_COMPRESS_LEVEL:+:${BTRFS_COMPRESS_LEVEL}}"
    fi
fi
render device/image/templates/boot/extlinux.conf.in "${CHROOT}"/boot/extlinux/extlinux.conf DTB_NAME ROOT_PARTUUID BOOT_ARGS

# Kernel and module files are readable by root only.
for d in boot usr/src lib/modules usr/lib/modules; do
    if [ -d "${CHROOT}/${d}" ]; then
        chmod 700 "${CHROOT}/${d}"
    fi
done
