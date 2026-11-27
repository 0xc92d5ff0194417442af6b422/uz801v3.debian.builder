#!/bin/sh -e

. ./lib/steps/common.sh

# Sets the host name and adds it to the localhost lines in /etc/hosts.
# A line that already ends with the name is left alone, so a second run of this step adds nothing.
echo "${HOST_NAME}" > "${CHROOT}"/etc/hostname
sed -i "/localhost/ { / ${HOST_NAME}\$/! s/\$/ ${HOST_NAME}/; }" "${CHROOT}"/etc/hosts
# Adds each HOSTS_ENTRIES line to /etc/hosts. A line already in the file is not added again.
printf '%s\n' "${HOSTS_ENTRIES}" | grep -vE '^[[:space:]]*(#|$)' | while IFS= read -r entry; do
    grep -qxF "${entry}" "${CHROOT}"/etc/hosts || printf '%s\n' "${entry}" >> "${CHROOT}"/etc/hosts
done

# A fixed machine ID is written when MACHINE_ID is set. Otherwise systemd makes one on first boot.
mkdir -p "${CHROOT}"/var/lib/dbus
if [ -n "${MACHINE_ID}" ]; then
    printf '%s\n' "${MACHINE_ID}" | grep -qE '^[0-9a-f]{32}$' || { echo "MACHINE_ID must be 32 lowercase hex characters"; exit 1; }
    echo "${MACHINE_ID}" > "${CHROOT}"/etc/machine-id
    echo "${MACHINE_ID}" > "${CHROOT}"/var/lib/dbus/machine-id
else
    : > "${CHROOT}"/etc/machine-id
    ln -sf /etc/machine-id "${CHROOT}"/var/lib/dbus/machine-id
fi

# The boot partition is mounted by its UUID.
render device/image/templates/boot/fstab.in "${CHROOT}"/etc/fstab BOOT_PARTUUID

if [ -n "${NTP_SERVERS}" ]; then
    mkdir -p "${CHROOT}"/etc/systemd/timesyncd.conf.d
    printf '[Time]\nNTP=%s\n' "${NTP_SERVERS}" > "${CHROOT}"/etc/systemd/timesyncd.conf.d/ntp.conf
fi
