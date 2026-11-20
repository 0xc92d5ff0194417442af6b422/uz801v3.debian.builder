#!/bin/sh -e

# Removes logs, caches and documentation that the device does not need.
rm -f "${CHROOT}"/var/log/bootstrap.log "${CHROOT}"/var/log/dpkg.log "${CHROOT}"/var/log/alternatives.log

rm -f "${CHROOT}"/etc/ssh/ssh_host_*

rm -rf "${CHROOT}"/debootstrap "${CHROOT}"/var/lib/apt/lists/* "${CHROOT}"/var/cache/apt/*
rm -rf "${CHROOT}"/usr/share/doc "${CHROOT}"/usr/share/man "${CHROOT}"/usr/share/info
rm -rf "${CHROOT}"/usr/share/bash-completion
find "${CHROOT}"/usr/share/locale -mindepth 1 -maxdepth 1 -type d ! -name "${LOCALE%%.*}" ! -name C -exec rm -rf {} +
find "${CHROOT}"/usr/share/zoneinfo -mindepth 1 -maxdepth 1 ! -name Etc ! -name "${TIMEZONE%%/*}" -exec rm -rf {} +
