#!/bin/sh -e

. ./lib/steps/common.sh

# Builds the two raw images from the rootfs tarball. img2simg makes each one sparse, so fastboot can flash it.
rm -f work/rootfs.raw
mkdir -p work/mnt

BOOT_DIR=$(mktemp -d)
trap 'rm -rf "${BOOT_DIR}"' EXIT
tar xf work/rootfs.tgz -C "${BOOT_DIR}" ./boot --exclude='./boot/linux.efi' --strip-components=2
make_boot_image "${BOOT_DIR}"

truncate -s "${ROOTFS_SIZE}" work/rootfs.raw
${ROOT_MKFS} work/rootfs.raw
# Boot files live in the separate boot image, so this copy skips them. It also skips the dev and root directories.
mount work/rootfs.raw work/mnt
tar xpf work/rootfs.tgz -C work/mnt --exclude='./boot/*' --exclude='./root/*' --exclude='./dev/*'

if [ "${USB_GADGET}" = yes ]; then
    cp -a work/dist/* work/mnt
fi

umount work/mnt

img2simg work/rootfs.raw work/files/rootfs.bin
