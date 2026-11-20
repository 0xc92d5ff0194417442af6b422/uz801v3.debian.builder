#!/bin/sh -e

export DEBIAN_FRONTEND=noninteractive

# Host packages for the image build. The kernel tools are added only when the kernel is built here.
apt-get update
apt-get install -y --no-install-recommends --no-install-suggests \
    android-sdk-libsparse-utils \
    autoconf \
    automake \
    binfmt-support \
    ca-certificates \
    cmake \
    debian-archive-keyring \
    debootstrap \
    device-tree-compiler \
    fdisk \
    g++-aarch64-linux-gnu \
    gcc-aarch64-linux-gnu \
    gcc-arm-none-eabi \
    git \
    iptables \
    libtool \
    make \
    pkg-config \
    python3-cryptography \
    python3-pyasn1-modules \
    python3-pycryptodome \
    qemu-user-static \
    unzip \
    wget \
    xfsprogs \
    btrfs-progs

if [ "${KERNEL_SOURCE}" = build ]; then
    apt-get install -y --no-install-recommends --no-install-suggests \
        bc \
        bison \
        flex \
        kmod \
        libelf-dev \
        libssl-dev \
        ccache \
        xz-utils \
        zstd
fi
