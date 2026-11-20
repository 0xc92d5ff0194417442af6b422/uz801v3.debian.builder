
# Checks a setting against a list of allowed words. A value with a space is rejected, because it is not one word.
check_choice() {
    choice=$(eval "printf '%s' \"\${$1}\"")
    case "${choice}" in
        *" "*) ;;
        *) case " $2 " in *" ${choice} "*) return 0 ;; esac ;;
    esac
    fail "$1 must be one of: $2 (got: ${choice})"
}


# Parallel jobs for make. Defaults to the number of CPUs.
MAKE_JOBS=${MAKE_JOBS:-$(nproc)}
MAKEFLAGS="-j${MAKE_JOBS}"
export MAKEFLAGS
ROOTFS_SIZE=${ROOTFS_SIZE:-1610612736}
BOOT_SIZE=${BOOT_SIZE:-67108864}
# The filesystem type sets the mkfs and resize commands below.
ROOT_FS=${ROOT_FS:-ext4}
check_choice ROOT_FS "ext4 btrfs xfs"
# btrfs compression applies only to a btrfs root. The level is checked against the range of each algorithm.
BTRFS_COMPRESS=${BTRFS_COMPRESS:-none}
check_choice BTRFS_COMPRESS "none lzo zlib zstd"
BTRFS_COMPRESS_LEVEL=${BTRFS_COMPRESS_LEVEL:-}
case "${BTRFS_COMPRESS}" in
    zlib|zstd)
        max=9
        [ "${BTRFS_COMPRESS}" = zstd ] && max=15
        if [ -n "${BTRFS_COMPRESS_LEVEL}" ]; then
            case "${BTRFS_COMPRESS_LEVEL}" in
                ''|*[!0-9]*) fail "BTRFS_COMPRESS_LEVEL must be a whole number" ;;
            esac
            if [ "${BTRFS_COMPRESS_LEVEL}" -lt 1 ] || [ "${BTRFS_COMPRESS_LEVEL}" -gt "${max}" ]; then
                fail "BTRFS_COMPRESS_LEVEL for ${BTRFS_COMPRESS} must be 1 to ${max}"
            fi
        fi
        ;;
    lzo)
        if [ -n "${BTRFS_COMPRESS_LEVEL}" ]; then
            fail "BTRFS_COMPRESS_LEVEL does not apply to lzo: leave it empty"
        fi
        ;;
esac
if [ "${BTRFS_COMPRESS}" != none ] && [ "${ROOT_FS}" != btrfs ]; then
    echo "WARNING: BTRFS_COMPRESS is ignored unless ROOT_FS=btrfs" >&2
fi
export BTRFS_COMPRESS BTRFS_COMPRESS_LEVEL
case "${ROOT_FS}" in
    ext4) ROOT_MKFS=mkfs.ext4; ROOT_RESIZE_CMD="/usr/sbin/resize2fs /dev/disk/by-partlabel/rootfs" ;;
    btrfs) ROOT_MKFS="mkfs.btrfs -f"; ROOT_RESIZE_CMD="/usr/bin/btrfs filesystem resize max /"
        EXTRA_PACKAGES="${EXTRA_PACKAGES:-} btrfs-progs" ;;
    xfs) ROOT_MKFS="mkfs.xfs -f"; ROOT_RESIZE_CMD="/usr/sbin/xfs_growfs /"
        EXTRA_PACKAGES="${EXTRA_PACKAGES:-} xfsprogs" ;;
esac
export ROOT_FS ROOT_MKFS ROOT_RESIZE_CMD
# zram swap: compressed swap in RAM. yes installs the driver, the swap service and the zram sysctls.
ZRAM=${ZRAM:-yes}
check_choice ZRAM "yes no"
export ZRAM
ZRAM_PERCENT=${ZRAM_PERCENT:-50}
TMP_SIZE=${TMP_SIZE:-10%}
USB_ADDRESS=${USB_ADDRESS:-192.168.254.1/24}
DEBIAN_MIRROR=${DEBIAN_MIRROR:-https://deb.debian.org/debian}
export MAKE_JOBS ROOTFS_SIZE BOOT_SIZE ZRAM_PERCENT TMP_SIZE USB_ADDRESS DEBIAN_MIRROR
for v in "${MAKE_JOBS}" "${ROOTFS_SIZE}" "${BOOT_SIZE}" "${ZRAM_PERCENT}"; do
    case "${v}" in
        ''|*[!0-9]*) v=0 ;;
    esac
    [ "${v}" -gt 0 ] || fail "MAKE_JOBS, ROOTFS_SIZE, BOOT_SIZE and ZRAM_PERCENT must be whole numbers above 0"
done
if [ "${BOOT_SIZE}" -gt 67108864 ]; then
    fail "BOOT_SIZE must be at most 67108864, the size of the boot partition"
fi

# Algorithm lists for sshd and the ssh client. Weak algorithms are left out of the defaults.
SSHD_CIPHERS=${SSHD_CIPHERS:-chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com}
SSHD_MACS=${SSHD_MACS:-hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256}
SSHD_KEX=${SSHD_KEX:-curve25519-sha256@libssh.org,diffie-hellman-group18-sha512,diffie-hellman-group16-sha512}
SSH_CIPHERS=${SSH_CIPHERS:-chacha20-poly1305@openssh.com,aes256-gcm@openssh.com}
SSH_MACS=${SSH_MACS:-hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com}
SSH_KEX=${SSH_KEX:-curve25519-sha256@libssh.org,diffie-hellman-group18-sha512}
SSH_GROUP=${SSH_GROUP:-ssh-user}
WHEEL_GROUP=${WHEEL_GROUP:-wheel}
# Masked services cannot start. The defaults cover units this device does not use.
MASK_SERVICES=${MASK_SERVICES:-getty@tty1.service e2scrub_reap.service networking.service systemd-pstore.service suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target}
ENABLE_SERVICES=${ENABLE_SERVICES:-systemd-networkd.service systemd-resolved.service systemd-timesyncd.service wpa_supplicant@wlan0.service}
export SSHD_CIPHERS SSHD_MACS SSHD_KEX SSH_CIPHERS SSH_MACS SSH_KEX SSH_GROUP WHEEL_GROUP MASK_SERVICES ENABLE_SERVICES
FIREWALL_RULES_V4_EXTRA=${FIREWALL_RULES_V4_EXTRA:-}
FIREWALL_RULES_V6_EXTRA=${FIREWALL_RULES_V6_EXTRA:-}
export FIREWALL_RULES_V4_EXTRA FIREWALL_RULES_V6_EXTRA

RELEASE=${RELEASE:-stable}
CPU_GOVERNOR=${CPU_GOVERNOR:-schedutil}
# Empty = no limit. The four cores share one clock, so the limit applies to all of them.
CPU_MAX_FREQ=${CPU_MAX_FREQ:-}
case "${CPU_MAX_FREQ}" in
    ''|*[!0-9]*) [ -z "${CPU_MAX_FREQ}" ] || fail "CPU_MAX_FREQ must be a frequency in kHz, for example 998400" ;;
esac
# LED triggers: green netdev (wlan0 rx and tx), blue mmc0 (eMMC), red activity (CPU load).
LED_GREEN_TRIGGER=${LED_GREEN_TRIGGER:-netdev}
LED_BLUE_TRIGGER=${LED_BLUE_TRIGGER:-mmc0}
LED_RED_TRIGGER=${LED_RED_TRIGGER:-activity}
UPGRADE_TIME=${UPGRADE_TIME:-03:00}
UPGRADE_DELAY=${UPGRADE_DELAY:-30min}
SECURITY_SUITE=${SECURITY_SUITE:-${RELEASE}-security}
NTP_SERVERS=${NTP_SERVERS:-}
CPU_ACTIVE_CORES=${CPU_ACTIVE_CORES:-}
# Core 0 must stay online. Empty = all cores stay online.
if [ -n "${CPU_ACTIVE_CORES}" ]; then
    case " ${CPU_ACTIVE_CORES} " in
        *" 0 "*) ;;
        *) fail "CPU_ACTIVE_CORES must include core 0" ;;
    esac
    for c in ${CPU_ACTIVE_CORES}; do
        case "${c}" in 0|1|2|3) ;; *) fail "CPU_ACTIVE_CORES must list cores 0 to 3, separated by spaces" ;; esac
    done
fi
export CPU_GOVERNOR CPU_MAX_FREQ CPU_ACTIVE_CORES LED_GREEN_TRIGGER LED_BLUE_TRIGGER LED_RED_TRIGGER UPGRADE_TIME UPGRADE_DELAY SECURITY_SUITE NTP_SERVERS RELEASE
if ! printf '%s\n' "${UPGRADE_TIME}" | grep -qE '^([01][0-9]|2[0-3]):[0-5][0-9]$'; then
    fail "UPGRADE_TIME must be a time of day, for example 03:00"
fi

# A random name is used when none is set, so two devices do not get the same name.
if [ -z "${HOST_NAME}" ]; then
    HOST_NAME="debian-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 8)"
    msg INFO "generated host name: ${HOST_NAME}"
fi
if ! printf '%s\n' "${HOST_NAME}" | grep -qE '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'; then
    fail "HOST_NAME must be 1 to 63 lowercase letters, digits or hyphens, not starting or ending with a hyphen"
fi
# Prebuilt kernel package. Used only when KERNEL_SOURCE=prebuilt.
KERNEL_APK_URL=${KERNEL_APK_URL:-https://mirror.postmarketos.org/postmarketos/v24.06/aarch64/linux-postmarketos-qcom-msm8916-6.6-r5.apk}
KERNEL_SHA256=${KERNEL_SHA256:-8166387eaca9189ff923e635857afb272886b433925a1a7a172d4ed2bab4baa9}
KERNEL_SOURCE=${KERNEL_SOURCE:-build}
export HOST_NAME KERNEL_APK_URL KERNEL_SHA256 KERNEL_SOURCE
check_choice KERNEL_SOURCE "build prebuilt"
if [ "${ONLY_KERNEL}" = yes ] && [ "${KERNEL_SOURCE}" != build ]; then
    fail "--only-kernel needs KERNEL_SOURCE=build"
fi
# yes applies the short option list in device/kernel. The default no keeps the base config.
# KERNEL_OPTIONS adds a custom list after it.
MINIMAL_KERNEL=${MINIMAL_KERNEL:-no}
check_choice MINIMAL_KERNEL "yes no"
KERNEL_OPTIONS=${KERNEL_OPTIONS:-}
if [ -n "${KERNEL_OPTIONS}" ] && [ ! -f "${KERNEL_OPTIONS}" ]; then
    fail "KERNEL_OPTIONS file not found: ${KERNEL_OPTIONS}"
fi
export MINIMAL_KERNEL KERNEL_OPTIONS
KEXEC=${KEXEC:-yes}
check_choice KEXEC "yes no"
export KEXEC
# Each patch is applied only when its switch is yes. The patch files are in device/kernel/patches.
PATCH_BBR=${PATCH_BBR:-yes}
PATCH_LE9UO=${PATCH_LE9UO:-yes}
PATCH_ZSTD=${PATCH_ZSTD:-yes}
PATCH_CPR=${PATCH_CPR:-yes}
PATCH_SMSM=${PATCH_SMSM:-yes}
for v in PATCH_BBR PATCH_LE9UO PATCH_ZSTD PATCH_CPR PATCH_SMSM; do check_choice "${v}" "yes no"; done
export PATCH_BBR PATCH_LE9UO PATCH_ZSTD PATCH_CPR PATCH_SMSM
# Where the journal is kept. Step 62 turns this setting and LOG_LEVEL into journald settings.
LOG_STORAGE=${LOG_STORAGE:-disk}
LOG_LEVEL=${LOG_LEVEL:-normal}
LOG_MAX_SIZE=${LOG_MAX_SIZE:-50M}
LOG_FORWARD=${LOG_FORWARD:-no}
LOG_FORWARD_TARGET=${LOG_FORWARD_TARGET:-}
LOG_SUDO=${LOG_SUDO:-yes}
DEBUG_SERVICES=${DEBUG_SERVICES:-no}
KERNEL_DEBUG=${KERNEL_DEBUG:-no}
CRASH_CAPTURE=${CRASH_CAPTURE:-no}
CRASH_CAPTURE_ADDR=${CRASH_CAPTURE_ADDR:-}
CRASH_CAPTURE_SIZE=${CRASH_CAPTURE_SIZE:-}
check_choice LOG_STORAGE "disk ram none"
check_choice LOG_LEVEL "full normal minimal none"
for v in LOG_FORWARD LOG_SUDO DEBUG_SERVICES KERNEL_DEBUG CRASH_CAPTURE; do check_choice "${v}" "yes no"; done
if [ "${LOG_FORWARD}" = yes ]; then
    case "${LOG_FORWARD_TARGET}" in
        *:*) ;;
        *) fail "LOG_FORWARD_TARGET must be host:port when LOG_FORWARD=yes" ;;
    esac
fi
if [ "${CRASH_CAPTURE}" = yes ] && { [ -z "${CRASH_CAPTURE_ADDR}" ] || [ -z "${CRASH_CAPTURE_SIZE}" ]; }; then
    fail "CRASH_CAPTURE=yes needs CRASH_CAPTURE_ADDR and CRASH_CAPTURE_SIZE"
fi
export LOG_STORAGE LOG_LEVEL LOG_MAX_SIZE LOG_FORWARD LOG_FORWARD_TARGET LOG_SUDO DEBUG_SERVICES KERNEL_DEBUG CRASH_CAPTURE CRASH_CAPTURE_ADDR CRASH_CAPTURE_SIZE
# Feature switches. Each one controls packages, kernel options and device tree nodes.
WIFI=${WIFI:-yes}
BLUETOOTH=${BLUETOOTH:-no}
MODEM=${MODEM:-no}
USB_GADGET=${USB_GADGET:-yes}
for v in WIFI BLUETOOTH MODEM USB_GADGET; do check_choice "${v}" "yes no"; done
# Two-letter regulatory domain. The Wi-Fi driver uses it to choose the allowed channels.
# There is no default, because a wrong country can break local radio law.
# Kernel-only, boot-only and WIFI=no builds do not use it, so they skip the check.
WIFI_COUNTRY=${WIFI_COUNTRY:-}
if [ "${ONLY_KERNEL}" != yes ] && [ -z "${ONLY_BOOT_DTB}" ] && [ "${WIFI}" = yes ] && [ -z "${WIFI_COUNTRY}" ]; then
    fail "set WIFI_COUNTRY in the config file, for example GB"
fi
if [ -n "${WIFI_COUNTRY}" ] && ! printf '%s\n' "${WIFI_COUNTRY}" | grep -qE '^[A-Z]{2}$'; then
    fail "WIFI_COUNTRY must be a two-letter country code, for example GB"
fi
export WIFI_COUNTRY
USB_GADGET_MODE=${USB_GADGET_MODE:-rndis}
check_choice USB_GADGET_MODE "rndis ecm cdc-ecm acm acm-ecm mass ffs hid"
export USB_GADGET_MODE
# The default no keeps every device tree node. Step 21 disables the unused ones with status overrides.
TRIM_DTB=${TRIM_DTB:-no}
check_choice TRIM_DTB "yes no"
export TRIM_DTB
# Without Wi-Fi, the Wi-Fi service leaves the enable list and is masked.
if [ "${WIFI}" = no ]; then
    ENABLE_SERVICES=$(printf '%s\n' ${ENABLE_SERVICES} | grep -v '^wpa_supplicant@wlan0.service$' | paste -sd' ' -)
    MASK_SERVICES="${MASK_SERVICES} wpa_supplicant@wlan0.service"
fi
if [ "${BLUETOOTH}" = yes ]; then
    EXTRA_PACKAGES="${EXTRA_PACKAGES:-} bluez"
fi
if [ "${KEXEC}" = yes ]; then
    EXTRA_PACKAGES="${EXTRA_PACKAGES:-} kexec-tools"
fi
if [ "${WIFI}" = yes ]; then
    EXTRA_PACKAGES="${EXTRA_PACKAGES:-} wpasupplicant wireless-regdb iw"
fi
if [ "${USB_GADGET}" = yes ]; then
    EXTRA_PACKAGES="${EXTRA_PACKAGES:-} libconfig11"
fi
# The modem firmware is not in the repository, so the build can only warn.
if [ "${MODEM}" = yes ]; then
    echo "WARNING: MODEM=yes needs the modem firmware (mba.mbn, mpss.mdt) in device/board/firmware; this build does not copy it" >&2
fi
export WIFI BLUETOOTH MODEM USB_GADGET ENABLE_SERVICES MASK_SERVICES EXTRA_PACKAGES
ADMIN_USER=${ADMIN_USER:-admin}
export ADMIN_USER
if ! printf '%s\n' "${ADMIN_USER}" | grep -qE '^[a-z_][a-z0-9_-]*$' || [ "${ADMIN_USER}" = root ]; then
    fail "ADMIN_USER must be a lowercase login name, not root"
fi

# Empty means sshd accepts connections from any address.
SSH_ALLOW_FROM=${SSH_ALLOW_FROM:-}
SSH_PORT=${SSH_PORT:-22}
export SSH_ALLOW_FROM SSH_PORT
case "${SSH_PORT}" in
    ''|*[!0-9]*) fail "SSH_PORT must be a port number" ;;
esac
if [ "${SSH_PORT}" -lt 1 ] || [ "${SSH_PORT}" -gt 65535 ]; then
    fail "SSH_PORT must be between 1 and 65535"
fi

# Area/Zone name. Step 71 keeps only this zone in the image.
TIMEZONE=${TIMEZONE:-Etc/UTC}
LOCALE=${LOCALE:-en_GB.UTF-8}
export TIMEZONE LOCALE
case "${TIMEZONE}" in
    */*) ;;
    *) fail "TIMEZONE must be Area/Zone, for example Europe/London" ;;
esac
