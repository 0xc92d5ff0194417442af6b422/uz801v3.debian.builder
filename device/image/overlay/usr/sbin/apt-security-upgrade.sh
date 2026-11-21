#!/bin/sh -e

# SECURITY_SUITE is set at build time in /etc/default/apt-security-upgrade
SECURITY_SUITE=stable-security
[ -f /etc/default/apt-security-upgrade ] && . /etc/default/apt-security-upgrade

apt-get update -qq

pkgs=$(apt list --upgradable 2>/dev/null | grep -- '-security' | cut -d/ -f1)
[ -z "${pkgs}" ] && exit 0

# pkgs stays unquoted, so each package name is a separate argument.
DEBIAN_FRONTEND=noninteractive apt-get -y -qq -t "${SECURITY_SUITE}" --only-upgrade install ${pkgs}
