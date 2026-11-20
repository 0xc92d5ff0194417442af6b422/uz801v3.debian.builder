#!/bin/sh -e

. ./lib/steps/common.sh

export LC_ALL=C
export LANG=C

# A saved debootstrap result. --use-base-cache restores it instead of running debootstrap again.
BASE_CACHE="work/cache/base-${RELEASE}.tar"

# The chroot always starts empty.
rm -rf --one-file-system "${CHROOT}"

if [ "${USE_BASE_CACHE}" = yes ] && [ -f "${BASE_CACHE}" ]; then
    echo "using cached base: ${BASE_CACHE}"
    mkdir -p "${CHROOT}"
    tar -xpf "${BASE_CACHE}" -C "${CHROOT}"
else
    # The first stage runs on the host. The second stage runs in the chroot under qemu.
    debootstrap --foreign --arch arm64 \
        --keyring /usr/share/keyrings/debian-archive-keyring.gpg "${RELEASE}" "${CHROOT}" "${DEBIAN_MIRROR}"

    cp "$(command -v qemu-aarch64-static)" "${CHROOT}"/usr/bin

    chroot "${CHROOT}" qemu-aarch64-static /bin/bash /debootstrap/debootstrap --second-stage

    mkdir -p work/cache
    tar -cpf "${BASE_CACHE}.tmp" -C "${CHROOT}" .
    mv "${BASE_CACHE}.tmp" "${BASE_CACHE}"
    echo "saved base cache: ${BASE_CACHE}"
fi

# Writes the apt sources. $1 is the main mirror. $2 is the scheme of the security mirror.
write_sources() {
    cat << SOURCES > "${CHROOT}"/etc/apt/sources.list
deb $1 ${RELEASE} main contrib non-free-firmware
deb $2://deb.debian.org/debian-security/ ${RELEASE}-security main contrib non-free-firmware
deb $1 ${RELEASE}-updates main contrib non-free-firmware
SOURCES
}

# Plain http for the first apt run. The chroot has no CA certificates until ca-certificates is installed.
BOOT_MIRROR=$(printf '%s' "${DEBIAN_MIRROR}" | sed 's#^https://#http://#')
write_sources "${BOOT_MIRROR}" http

# The chroot needs the proc, sys, dev and run filesystems. unmount_all removes them.
mount -t proc proc "${CHROOT}"/proc/
mount -t sysfs sys "${CHROOT}"/sys/
mount -o bind /dev/ "${CHROOT}"/dev/
mount -o bind /dev/pts/ "${CHROOT}"/dev/pts/
mount -o bind /run "${CHROOT}"/run/

chroot "${CHROOT}" qemu-aarch64-static /bin/sh -c "apt-get update && apt-get install -y --no-install-recommends ca-certificates"

write_sources "${DEBIAN_MIRROR}" https

# The chroot setup runs once, after the image sources are in place.
cp lib/steps/chroot/setup-base-system.sh "${CHROOT}"/setup.sh
chroot "${CHROOT}" qemu-aarch64-static /bin/sh -c /setup.sh

unmount_all

rm -f "${CHROOT}"/setup.sh
: > "${CHROOT}"/root/.bash_history
