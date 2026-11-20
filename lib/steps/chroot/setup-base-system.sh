#!/bin/sh -e

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# Preseed answers for tzdata and locales, so apt does not ask questions.
debconf-set-selections << EOF
tzdata tzdata/Areas select ${TIMEZONE%%/*}
tzdata tzdata/Zones/${TIMEZONE%%/*} select ${TIMEZONE#*/}
locales locales/default_environment_locale select ${LOCALE}
locales locales/locales_to_be_generated multiselect ${LOCALE} UTF-8
EOF
rm -f "/etc/locale.gen"

# Refuses insecure sources and redirects, and keeps the apt sandbox on.
cat << EOF > /etc/apt/apt.conf.d/90-hardening.conf
Acquire::AllowDowngradeToInsecureRepositories "false";
Acquire::AllowInsecureRepositories "false";
Acquire::http::AllowRedirect "false";
APT::Get::AllowUnauthenticated "false";
APT::Get::AutomaticRemove "true";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APT::Periodic::AutocleanInterval "7";
APT::Sandbox::Seccomp "1";
Dir::Log::History "";
Dir::Log::Terminal "";
EOF

# Brings the chroot up to date, then installs the packages the image needs.
apt-get update -qqy
apt-get upgrade -qqy
apt-get autoremove -qqy
apt-get install -qqy --no-install-recommends \
    cracklib-runtime \
    iptables \
    libpam-pwquality \
    wamerican \
    locales \
    openssh-server \
    sudo \
    systemd-resolved \
    systemd-timesyncd \
    tzdata \
    ${EXTRA_PACKAGES}
apt-get clean
rm -rf /var/lib/apt/lists/*

# Removes default system accounts that the device does not use.
for u in games news sync uucp list irc; do
    userdel -r "$u" 2>/dev/null || true
done

# Compilers stay installed, but only root can run them. A normal user cannot build code on the device.
find /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin -maxdepth 5 \( -name as -o -name cargo -o -name cc -o -name 'cc-[0-9]*' -o -name 'clang-[0-9]*' -o -name gcc -o -name 'gcc-[0-9]*' -o -name go -o -name make -o -name rustc \) -print | while read -r f; do
    chmod 0750 "$f"
    dpkg-statoverride --update --force-all --add root root 0750 "$f"
done

# Masks the services in MASK_SERVICES, then enables the ones in ENABLE_SERVICES.
systemctl mask ${MASK_SERVICES}
systemctl enable ${ENABLE_SERVICES}

# Clears the setuid and setgid bits. Only the listed tools keep them.
find /usr /bin /sbin -xdev -type f \( -perm -4000 -o -perm -2000 \) | while read -r f; do
    case "$f" in
        /usr/bin/sudo|/usr/bin/passwd|/usr/sbin/unix_chkpwd|/usr/lib/dbus-1.0/dbus-daemon-launch-helper) continue ;;
    esac
    chmod a-s "$f"
    dpkg-statoverride --update --force-all --add root root 0755 "$f"
done

# Creates the admin account. Its password is set below, and the root login is locked.
echo "${ADMIN_USER}:!::::/home/${ADMIN_USER}:/bin/bash" | newusers
echo "${ADMIN_USER}:${ADMIN_PASSWORD}" | chpasswd
passwd -l root
# The SSH group allows login. The wheel group allows sudo. The admin account joins both.
groupadd -f "${SSH_GROUP}"
groupadd -f "${WHEEL_GROUP}"
usermod -aG "${SSH_GROUP},${WHEEL_GROUP}" "${ADMIN_USER}"
install -d -m 0700 -o "${ADMIN_USER}" -g "${ADMIN_USER}" /home/"${ADMIN_USER}"
printf '%%%s ALL=(ALL:ALL) ALL\n' "${WHEEL_GROUP}" > /etc/sudoers.d/"${WHEEL_GROUP}"
chmod 0440 /etc/sudoers.d/"${WHEEL_GROUP}"
