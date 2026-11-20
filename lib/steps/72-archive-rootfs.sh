#!/bin/sh -e

# qemu is excluded from the archive. It is only needed during the build.
tar cpzf work/rootfs.tgz --exclude="usr/bin/qemu-aarch64-static" -C "${CHROOT}" .
