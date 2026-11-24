# uz801v3.debian.builder

uz801v3.debian.builder builds a Debian arm64 image for the [UZ801 v3 USB 4G and Wi-Fi stick](https://www.aliexpress.com/item/1005010169664336.html). The board uses a Qualcomm MSM8916 chip. 

The build runs on an x86 Linux host. One run makes the bootloader, the kernel, the root filesystem and the flash images.

## Features

- Debian `trixie` root filesystem, built with debootstrap. The arm64 steps run under qemu.
- Kernel 6.12.118 (LTS), built from source, with optional patches: BBR v3, LE9UO, zstd, CPR and SMSM. The CPR patch adds the higher CPU frequencies (1094400, 1152000 and 1209600 kHz) [*](docs/kernel.md#patches)
- Root filesystem as ext4, xfs or btrfs. btrfs can compress the data.
- Wi-Fi, Bluetooth, modem and USB gadget modes. You set each one in `config.env`.
- SSH with key-only login and a firewall.
- Optional zram swap.
- Trimmed device tree (`TRIM_DTB="yes"`). The usable memory rises from 317 MB to 476 MB. [*](docs/kernel.md#device-tree-trimming)
- One file, `config.env`, holds all settings. A failed build can resume from a step.
- A Docker image for the build.

## Quick start

1. Copy an example file and set the required values:

   ```sh
   cp config/config.env.example config.env
   chmod 600 config.env
   ```

   Set `ADMIN_SSH_KEYS`, `WIFI_SSID`, `WIFI_PASSWORD` and `WIFI_COUNTRY`.

2. Run the build as root:

   ```sh
   sudo sh build.sh
   ```

3. Get the images from `work/files/`.

To build in Docker, see [Docker build](docs/docker.md).

## Documentation

- [Build](docs/build.md): requirements, steps, switches and outputs.
- [Setup](docs/configuration.md): required values and example files.
- [Kernel](docs/kernel.md): kernel options, patches and device tree trimming.
- [Device](docs/device.md): first boot, network, SSH, LEDs and logs.
- [Debian configuration](docs/debian-configuration.md): packages, hardening, SSH, firewall, services and scripts.
- [Docker build](docs/docker.md): build and run the image in a container.
- [Kernel update](docs/kernel-update.md): install a new kernel on a running device.

## License

See [LICENSE](LICENSE).
