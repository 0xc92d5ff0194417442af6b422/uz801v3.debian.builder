# Configuration

The build reads its values from one file, `config.env`. Each value has a default in `lib/settings.sh`. If you leave a value out, the build uses its default.

## Files

| File | Purpose |
|---|---|
| `config.env` | Your values. It holds passwords and keys, so keep it at mode 600. Git ignores it. |
| `config/config.env.example` | Full example with every value and its comment. Start from this file. |
| `config/config.env.debug.example` | Example for debugging. It turns on kernel debug options, systemd debug logs and crash capture. |
| `config/config.env.minimal.example` | Example for a small image with fewer drivers and features. |

Copy one example to `config.env`, then change the values you need:

```sh
cp config/config.env.example config.env
chmod 600 config.env
```

The file is read as plain text, not run as a shell script. Write each value as `NAME="value"`. Text such as `$`, backquotes and backslashes stays as typed. A quoted value can span several lines. Only spaces or a `#` comment may follow the closing quote. The build removes Windows line endings, so a file edited on Windows still works.

## Required values

If one of these values is missing, the build stops at startup. The error names the missing value.

| Value | Notes |
|---|---|
| `ADMIN_SSH_KEYS` | One or more `ssh-ed25519` public keys, one per line. The build rejects other key types. |
| `WIFI_SSID`, `WIFI_PASSWORD` | Needed for Wi-Fi (`WIFI="yes"`). The password is 8 to 63 characters. |
| `WIFI_COUNTRY` | Two-letter country code, for example `GB`. The Wi-Fi driver uses it to pick channels. Needed for Wi-Fi (`WIFI="yes"`). |

`--only-kernel` and `--only-boot` do not need the Wi-Fi and SSH values.

## Values by area

The example file groups the values. The tables below list the main ones.

### Admin account and SSH

| Value | Default | Effect |
|---|---|---|
| `ADMIN_USER` | `admin` | The login name. It cannot be `root`. |
| `ADMIN_PASSWORD` | generated | If empty, the build makes a random 24 character password and prints it at the end. |
| `SSH_PORT` | `22` | The port for sshd. The firewall opens it on wlan0 and usb0. |
| `SSH_ALLOW_FROM` | empty | Space-separated addresses or subnets. If empty, every address is allowed. |
| `SSH_GROUP`, `WHEEL_GROUP` | `ssh-user`, `wheel` | Groups for SSH login and sudo. |

### Wi-Fi and network

| Value | Default | Effect |
|---|---|---|
| `WIFI` | `yes` | Builds the Wi-Fi drivers and firmware loader. Set it to `no` to remove them. |
| `WIFI_MAC` | empty | A fixed MAC address. If empty, the device makes a random address on first boot. |
| `DNS_SERVER` | empty | If empty, the device uses the DNS servers from DHCP. A value replaces them. |
| `USB_ADDRESS` | `192.168.254.1/24` | The device address on the USB network interface. |

### USB gadget

| Value | Default | Effect |
|---|---|---|
| `USB_GADGET` | `yes` | Builds the gadget functions. With `yes`, the kernel has no USB host drivers. With `no`, the build adds no gadget functions and turns the USB host drivers on. |
| `USB_GADGET_MODE` | `rndis` | The USB functions the gadget offers. See the modes below. |

Gadget modes:

| Mode | USB functions | What the host sees |
|---|---|---|
| `rndis` | RNDIS network | An Ethernet network. The device gets `USB_ADDRESS` on `usb0`. |
| `ecm` | CDC ECM network | An Ethernet network. The device gets `USB_ADDRESS` on `usb0`. |
| `cdc-ecm` | CDC ECM network | The same as `ecm`. The build accepts it as a second name. |
| `acm` | ACM serial port | A serial port. No network. |
| `acm-ecm` | ACM serial port and CDC ECM network | A serial port and an Ethernet network. The device gets `USB_ADDRESS` on `usb0`. |
| `mass` | Mass storage | A disk. The gadget scheme `device/image/templates/gadget/schemes/mass.scheme` sets the image. |
| `ffs` | FunctionFS | A user-space program provides the function. |
| `hid` | HID | A human interface device. A user-space program sends the reports. |

Only the network modes (`rndis`, `ecm`, `cdc-ecm` and `acm-ecm`) get the `usb0` network file.

### Hardware features

| Value | Default | Effect |
|---|---|---|
| `BLUETOOTH` | `no` | Adds the Bluetooth drivers, the bluez package and the wcnss_bt device tree node. |
| `MODEM` | `no` | Adds the modem kernel options and device tree nodes. The modem firmware is not in the repository. |
| `TRIM_DTB` | `no` | `yes` deletes the unused device tree nodes and raises the usable memory to 476 MB. `no` keeps them, disables the GPU, display and video nodes, and leaves the usable memory at 317 MB. |
| `KEXEC` | `yes` | Builds kexec and suspend support. `no` also sets `kernel.kexec_load_disabled = 1`, which blocks kexec at runtime. |

### Kernel

| Value | Default | Effect |
|---|---|---|
| `KERNEL_SOURCE` | `build` | `build` compiles the kernel. `prebuilt` downloads the postmarketOS package. |
| `MINIMAL_KERNEL` | `no` | `yes` applies `device/kernel/minimal-kernel.txt`, which removes most drivers. |
| `KERNEL_OPTIONS` | empty | The path to a custom options file. The build applies it after the minimal list. |
| `PATCH_BBR`, `PATCH_LE9UO`, `PATCH_ZSTD`, `PATCH_CPR`, `PATCH_SMSM` | `yes` | Each one turns a kernel patch on or off. See [kernel](kernel.md). |

### Root filesystem

| Value | Default | Effect |
|---|---|---|
| `ROOT_FS` | `ext4` | `ext4`, `btrfs` or `xfs`. The image uses this filesystem. |
| `BTRFS_COMPRESS` | `none` | Compression for the btrfs root: `none`, `lzo`, `zlib` or `zstd`. It works only with `ROOT_FS=btrfs`. Any value except `none` adds `rootflags=compress=...` to the kernel command line. |
| `BTRFS_COMPRESS_LEVEL` | empty | The level for `zstd` (1 to 15) or `zlib` (1 to 9). If empty, the default level is used. The build adds it after the algorithm as `:LEVEL`. |
| `ROOTFS_SIZE` | 1.5 GiB | The size of the root image. The root partition grows to the full eMMC on first boot. Set it slightly above the `rootfs.bin` data size to shorten the flash duration of the rootfs partition. |
| `BOOT_SIZE` | 64 MiB | The size of the boot image. It cannot be larger than the boot partition. |

### Kernel frequency limit

| Setting | Default | Effect |
|---|---|---|
| `CPU_MAX_FREQ` | empty | The maximum CPU frequency in kHz. The four cores share one clock, so the limit applies to all of them. If empty, there is no limit. With `PATCH_CPR="yes"`, the frequencies are 200000, 400000, 533333, 800000, 998400, 1094400, 1152000 and 1209600 kHz. `PATCH_CPR` adds 1094400, 1152000 and 1209600. Without it, the highest frequency is 998400. |
| `CPU_ACTIVE_CORES` | empty | The cores that stay online, separated by spaces (0 to 3). Core 0 must be listed. The build takes the other cores offline at boot. If empty, all cores stay online. |

### Swap and memory

| Value | Default | Effect |
|---|---|---|
| `ZRAM` | `yes` | Compressed swap in RAM. `no` removes the driver, the swap service and their defaults. |
| `ZRAM_PERCENT` | `50` | The size of the zram swap, as a percentage of RAM. It applies only with `ZRAM=yes`. |
| `TMP_SIZE` | `10%` | The size of `/tmp`, a tmpfs. |

### LEDs

| Value | Default | Effect |
|---|---|---|
| `LED_RED_TRIGGER` | `activity` | The red LED (power). `activity` follows CPU load. |
| `LED_GREEN_TRIGGER` | `netdev` | The green LED. `netdev` follows Wi-Fi receive and transmit on wlan0. |
| `LED_BLUE_TRIGGER` | `mmc0` | The blue LED. `mmc0` follows eMMC activity. |

### Logging

| Value | Default | Effect |
|---|---|---|
| `LOG_STORAGE` | `disk` | `disk` keeps the journal on the eMMC. `ram` keeps it in memory. `none` turns it off. |
| `LOG_LEVEL` | `normal` | `full`, `normal`, `minimal` or `none`. |
| `LOG_MAX_SIZE` | `50M` | The journal size limit. |
| `LOG_FORWARD` | `no` | Sends logs to `LOG_FORWARD_TARGET` (`host:port`). |
| `WATCHDOG` | `no` | Installs the watchdog daemon and enables it at boot. The daemon reboots the device when it stops feeding the watchdog for 60 seconds. The timeout and interval are in `device/image/overlay/watchdog/etc/watchdog.conf`. |
| `DEBUG_SERVICES` | `no` | Sets systemd to write debug output in the image. |

## Rules for values

When the build starts, it checks the values that accept a fixed list of words. An unknown word stops the build, and the error lists the allowed words.

Numbers such as `ROOTFS_SIZE`, `BOOT_SIZE`, `MAKE_JOBS` and `SSH_PORT` must be whole numbers.

`BTRFS_COMPRESS_LEVEL` must be empty for `lzo`.

With `ROOT_FS=btrfs` and `BTRFS_COMPRESS` set, the build adds `rootflags=compress=ALGO[:LEVEL]` to the kernel command line. The root mounts with compression. The build does not add `noatime`.

The build prints a warning for a value that has no effect. For example, `BTRFS_COMPRESS` has no effect on an ext4 root.

## Secrets

`config.env` holds the Wi-Fi password, the admin password and any keys you add. Do not commit it.

The build writes the admin password and the Wi-Fi password to `work/files/device-info.env`. It also writes the admin password to the build log. Both files have mode 600.
