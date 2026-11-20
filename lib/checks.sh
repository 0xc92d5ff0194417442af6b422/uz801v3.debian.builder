
# Kernel-only and boot-only builds skip the Wi-Fi and SSH checks, because they do not use those settings.
if [ "${ONLY_KERNEL}" != yes ] && [ -z "${ONLY_BOOT_DTB}" ]; then
    if [ "${WIFI}" = yes ]; then
        : "${WIFI_SSID:?set WIFI_SSID in the config file or the environment}"
        : "${WIFI_PASSWORD:?set WIFI_PASSWORD in the config file or the environment}"
        if [ "${#WIFI_PASSWORD}" -lt 8 ] || [ "${#WIFI_PASSWORD}" -gt 63 ]; then
            fail "WIFI_PASSWORD must be 8 to 63 characters"
        fi
    fi
    : "${ADMIN_SSH_KEYS:?set ADMIN_SSH_KEYS in the config file or the environment}"
    # Only ed25519 keys are accepted. This counts the lines that do not match.
    bad_keys=$(printf '%s\n' "${ADMIN_SSH_KEYS}" | grep -v '^$' | grep -vc '^ssh-ed25519 ' || true)
    if [ "${bad_keys}" != 0 ]; then
        fail "ADMIN_SSH_KEYS: every key must be an ssh-ed25519 key (sshd accepts no other key type)"
    fi
fi
