# Services

Services are enabled or masked in `lib/steps/chroot/setup-base-system.sh` and `lib/steps/61-install-systemd-units.sh`.

## Enabled and masked

Step 61 masks the units in `MASK_SERVICES`. It enables the units in `ENABLE_SERVICES`. The build removes `wpa_supplicant@wlan0.service` from the enabled list when `WIFI="no"`.

The default enabled units are `systemd-networkd`, `systemd-resolved`, `systemd-timesyncd` and `wpa_supplicant@wlan0`.

The default masked units are `getty@tty1`, `e2scrub_reap`, `networking`, `systemd-pstore`, and the suspend and hibernate targets.

## Units from the overlay

| Unit | Starts | Action | Condition |
|---|---|---|---|
| `firewall.service` | multi-user | Loads the IPv4 and IPv6 rules. | Always. |
| `zram-swap.service` | multi-user | Runs `zram-swap.sh start`. | `ZRAM="yes"`. Removed otherwise. |
| `thp-disable.service` | multi-user | Turns off transparent huge pages. | The kernel has the file. |
| `ssh-hostkeys.service` | multi-user | Creates the Ed25519 host key. No RSA or ECDSA key is made. | The Ed25519 host key is missing. |
| `wcnss-mac-address.service` | sysinit | Creates the Wi-Fi MAC address. | The MAC file is missing. |
| `wifi-powersave-off.service` | multi-user | Runs `iw dev wlan0 set power_save off`. | `WIFI="yes"`. Removed otherwise. |
| `apt-security-upgrade.service` | Timer | Installs security updates. | Runs at `UPGRADE_TIME` with a random delay up to `UPGRADE_DELAY`. |
| `led-boot-animation.service` | multi-user | Runs `led-boot.sh animate`. | Always. |
| `led-progress-sysinit.service` | basic | Runs `led-boot.sh progress blue:wan`. | Always. |
| `led-progress-basic.service` | multi-user | Runs `led-boot.sh progress red:power`. | Always. |
| `led-progress-multiuser.service` | multi-user | Runs `led-boot.sh progress green:wlan`. | Always. |

## Units from templates

| Unit | Starts | Action |
|---|---|---|
| `resize-rootfs.service` | Boot | Grows the root filesystem to fill its partition. It runs `resize2fs`, `btrfs filesystem resize max /` or `xfs_growfs /`, depending on `ROOT_FS`. It runs once and writes `/var/lib/resize-rootfs.done`. |
| `tmp.mount` | multi-user | Mounts `/tmp` in memory, with size `TMP_SIZE`. |
| `cpu-governor.service` | multi-user | Sets the CPU governor to `CPU_GOVERNOR`, the maximum frequency to `CPU_MAX_FREQ`, and the online cores to `CPU_ACTIVE_CORES`. It also turns off the deep idle state (`cpuidle/state1`) on every core. |
| `led-triggers.service` | multi-user | Sets the LED triggers for Wi-Fi, eMMC and CPU activity, after the LED animation ends. |
| `usb-gadget.service` | multi-user | Loads the USB gadget scheme for `USB_GADGET_MODE`. Only with `USB_GADGET="yes"`. |
| `log-forward.service` | multi-user | Forwards the journal. Only with `LOG_FORWARD="yes"`. |

## Drop-ins

- `cron.service.d/hardening.conf` runs cron with `NoNewPrivileges`, `PrivateTmp` and `ProtectHome`.
- `wpa_supplicant.service.d/hardening.conf` applies the same limits to `wpa_supplicant`.

The watchdog service is described in [Watchdog](watchdog.md).
