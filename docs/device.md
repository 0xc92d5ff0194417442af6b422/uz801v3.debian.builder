# Device

## Tested hardware

The images were tested on the device from this listing: [AliExpress item 1005010169664336](https://www.aliexpress.com/item/1005010169664336.html).

The board layout is below. The PCB colour on your device can differ.

![UZ801 v3.2 PCB layout](https://wiki.nura.eco/images/3/34/UZ801_V3.2_PCB.jpg)

## Flashing

The flashing steps are in the OpenStick guide for this board: [UZ801 flashing](https://openstick.org/boards/uz801/flashing/).

## First boot

The device boots the kernel from `/boot/extlinux/extlinux.conf`. The file has a `label` line, because lk2nd stops at a file with no label. The boot entry finds the root partition by its PARTUUID. The first boot does three things:

1. The `resize-rootfs` service runs once. It grows the root filesystem to fill the eMMC partition.
2. The clock is set from the network. Until then, it starts at the last saved time.
3. The LEDs show the boot stages. After that, they show their normal triggers.

The stages light the LEDs in this order:

| Stage | LED | Meaning |
|---|---|---|
| Storage ready | Blue (`blue:wan`) | Early system start is done. |
| Basic system ready | Red (`red:power`) | The basic targets are reached. |
| Services started | Green (`green:wlan`) | Multi-user services are started. |

When a stage starts, its LED blinks twice and then stays on. When systemd reports `running`, all three LEDs blink together twice and turn off. The normal triggers start after that.

If a service fails, systemd reports `degraded` instead of `running`. The stage LEDs stop. All three LEDs then blink together every 0.1 s until the next boot without failures. The normal triggers stay off in this case. To find the failed unit, run `systemctl --failed` as root.

## Admin account

The build creates one admin account. Its name comes from `ADMIN_USER`. The password is in `work/files/device-info.env` on the build host.

Log in over SSH with the key in `ADMIN_SSH_KEYS`:

```sh
ssh admin@<device-address>
```

The account has `sudo` through the wheel group. The root account is locked.

## Reboot to bootloader

On the device, run:

```sh
sudo systemctl reboot --reboot-argument=bootloader
```

On the host, with the device connected over USB, run:

```sh
fastboot devices
```

## EDL mode

To enter EDL mode in software, the bootloader must list `oem reboot-edl`. Run `fastboot oem help` to check.

1. Hold the button for at least 2 seconds while you power on the device. The device starts in fastboot mode.
2. On the host, run `fastboot devices` to check the connection.
3. Run this command:

```sh
fastboot oem reboot-edl
```

The device then enters EDL mode and appears as a Qualcomm 9008 device.

## Network

### Wi-Fi

The device joins the network named in `WIFI_SSID`. It gets its address from DHCP. Wi-Fi power save is off, so the link responds quickly.

`WIFI_MAC` sets a fixed hardware address. If it is empty, the device makes a random address on first boot.

### USB

The USB port runs as a gadget. The default mode, `rndis`, creates a network interface named `usb0`. The device uses `USB_ADDRESS`, which defaults to `192.168.254.1/24`.

The host computer needs an address on the same subnet, for example `192.168.254.2`. The device does not run a DHCP server on `usb0`, so set the host address by hand.

### Firewall

The firewall allows SSH on `SSH_PORT` over `wlan0` and `usb0`. IPv6 drops all traffic by default. `FIREWALL_RULES_V4_EXTRA` and `FIREWALL_RULES_V6_EXTRA` add rules before the `COMMIT` line.

## Root filesystem

`ROOT_FS` sets the root filesystem type:

| Type | Grow command | Notes |
|---|---|---|
| ext4 | `resize2fs` | The default. Mounted with the kernel defaults. |
| btrfs | `btrfs filesystem resize max /` | Mounted with the kernel defaults. If `BTRFS_COMPRESS` is set, the mount also adds `compress=ALGO[:LEVEL]`. |
| xfs | `xfs_growfs /` | Mounted with the default options. |

The `resize-rootfs` service runs the grow command once. To grow the filesystem again, run the command for your type as root.

If `BTRFS_COMPRESS` is set, the build adds one option to the kernel command line for the root: `rootflags=compress=...`. Do not add `rootflags=noatime` to `BOOT_ARGS`. On the test device, that option stopped the boot.

## Swap

With `ZRAM="yes"`, the device has a compressed swap device in RAM. Its size is `ZRAM_PERCENT` of RAM. The service is `zram-swap`. To check it, run:

```sh
swapon --show
```

With `ZRAM="no"`, the device has no swap.

## LEDs

The three LEDs follow the triggers in the config:

| LED | Default trigger | Shows |
|---|---|---|
| Red (`red:power`) | `activity` | CPU load. |
| Green (`green:wlan`) | `netdev` | Wi-Fi receive and transmit on `wlan0`. |
| Blue (`blue:wan`) | `mmc0` | eMMC activity. |

The `led-triggers` service sets these triggers after the boot animation ends. Without the service, the LEDs keep their boot state.

## Logs

The journal is kept on the eMMC by default. `LOG_STORAGE` moves it to RAM or turns it off. `LOG_MAX_SIZE` sets the size limit.

Root can read the journal. So can members of the `adm` and `systemd-journal` groups:

```sh
journalctl -b -p warning
```

`-b` shows the current boot. `-p warning` shows warnings and errors.

Set `DEBUG_SERVICES="yes"` in the config to make systemd write debug messages. To change the level on a running device, run `systemctl log-level debug` as root. The change lasts until the next boot.

## Build details

The build writes `work/files/device-info.env` on the host. It holds the host name, the partition IDs and the build date. The device does not get this file.
