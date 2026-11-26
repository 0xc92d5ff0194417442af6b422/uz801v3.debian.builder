#!/bin/sh -e

. ./lib/steps/common.sh

# sshd -t checks the config at the end of this step.
cp device/image/templates/ssh/ssh_config.in "${CHROOT}"/etc/ssh/ssh_config

render device/image/templates/ssh/sshd_config.in "${CHROOT}"/etc/ssh/sshd_config SSH_PORT ADMIN_USER SSH_GROUP

# With SSH_ALLOW_FROM set, a Match block denies login from every other address.
if [ -n "${SSH_ALLOW_FROM}" ]; then
    if printf '%s\n' ${SSH_ALLOW_FROM} | grep -qvE '^[0-9a-fA-F:.]+(/[0-9]+)?$'; then
        echo "SSH_ALLOW_FROM must be IP addresses or CIDR subnets, separated by spaces"
        exit 1
    fi
    nets=$(printf '!%s,' ${SSH_ALLOW_FROM} | sed 's/,$//')
    printf 'Match Address *,%s\n    DenyUsers *\n' "${nets}" >> "${CHROOT}"/etc/ssh/sshd_config
fi

# The admin account public keys. The files belong to the admin user, so sshd accepts them.
u="${ADMIN_USER}"
mkdir -p "${CHROOT}"/home/"${u}"/.ssh
printf '%s\n' "${ADMIN_SSH_KEYS}" > "${CHROOT}"/home/"${u}"/.ssh/authorized_keys
chmod 700 "${CHROOT}"/home/"${u}"/.ssh
chmod 600 "${CHROOT}"/home/"${u}"/.ssh/authorized_keys
chroot "${CHROOT}" qemu-aarch64-static /bin/chown -R "${u}:${u}" /home/"${u}"/.ssh

# sshd -t needs a host key. Step 71 removes every host key, so each device makes its own on first boot.
# Only Ed25519 is made. ssh-keygen -A would also make RSA and ECDSA keys.
mkdir -p "${CHROOT}"/run/sshd
# The base system may already have this key. ssh-keygen would then ask to overwrite it and fail, so the key is made only when missing.
if [ ! -f "${CHROOT}"/etc/ssh/ssh_host_ed25519_key ]; then
    chroot "${CHROOT}" qemu-aarch64-static /usr/bin/ssh-keygen -q -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
fi
chroot "${CHROOT}" qemu-aarch64-static /usr/sbin/sshd -t
