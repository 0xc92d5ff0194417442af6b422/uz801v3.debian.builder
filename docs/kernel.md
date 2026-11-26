# Kernel

The build compiles [Linux 6.12.118 (LTS)](https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.118.tar.xz) for the MSM8916 chip. It applies a base config from a pinned postmarketOS commit. Then it applies the options that the build needs and the patches you turn on.

## Source and checks

- The build downloads the source from `KERNEL_SRC_URL`, the 6.12.118 tarball linked above. It checks the SHA-512 of the tarball before it unpacks it.
- The base config comes from a postmarketOS commit. The build checks its SHA-512 too.
- `KERNEL_SOURCE=prebuilt` skips the compile and installs the postmarketOS package. Set `KERNEL_APK_URL` and `KERNEL_SHA256` with it.

## Option lists

The build edits `.config` in three passes:

1. Minimal list. `MINIMAL_KERNEL="yes"` applies `device/kernel/minimal-kernel.txt`. The list turns off most drivers. The default is `no`.
2. Custom file. `KERNEL_OPTIONS` names a file with `CONFIG_X=value` and `# CONFIG_X is not set` lines. The build applies it after the minimal list, so it can override the list.
3. Feature blocks. The build sets the options that each feature needs. Examples are Wi-Fi, Bluetooth, modem, USB gadget, kexec, debugging, crash capture and the root filesystem. These run last, so they override the first two passes. The hashlimit match (`CONFIG_NETFILTER_XT_MATCH_HASHLIMIT=m`) is always on, because the firewall rate limit for SSH needs it.

A feature block can override an option set in a custom file.

## Kernel trimming

`MINIMAL_KERNEL="yes"` applies `device/kernel/minimal-kernel.txt` to the kernel config. The table shows the options in `device/kernel/minimal-kernel.txt` by area. The areas come from the option name prefixes, so an option can sit in a neighbouring area.

| Area | Off | `m` | `y` | Examples |
|---|---:|---:|---:|---|
| Human input (HID, touch, keyboard) | 154 | 1 | 0 | `INPUT_TOUCHSCREEN`, `HID_SUPPORT`, `HID_A4TECH` |
| Crypto API and crypto code | 31 | 41 | 0 | `CRYPTO_DES`, `CRYPTO_MD4`, `CRYPTO_AES_TI` |
| Networking | 57 | 3 | 3 | `AX88796B_PHY`, `INET_TUNNEL`, `RMNET` |
| Graphics and display | 59 | 0 | 0 | `MEDIA_SUPPORT`, `CEC_CORE`, `DRM_DISPLAY_CONNECTOR` |
| Sound | 51 | 0 | 0 | `SND_ALOOP`, `SND_HWDEP`, `SND_RAWMIDI` |
| Sensors and accelerometers | 43 | 0 | 0 | `AK8975`, `BMC150_ACCEL`, `BMC150_ACCEL_I2C` |
| Platform and SoC drivers (Qualcomm and ARM) | 9 | 17 | 6 | `QCOM_APR`, `QCOM_BAM_DMUX`, `QCOM_FASTRPC` |
| USB | 21 | 5 | 4 | `USB_NET_AX88179_178A`, `USB_NET_AX8817X`, `USB_NET_CDCETHER` |
| Wireless and Bluetooth | 25 | 1 | 0 | `BT_BCM`, `BT_BNEP`, `BT_HCIBTUSB` |
| Block devices and I/O schedulers | 22 | 3 | 0 | `BLK_DEV_NBD`, `BLK_DEV_SR`, `BLK_DEV_UBLK` |
| Debug, tracing and accounting | 21 | 1 | 0 | `EDAC`, `ARM_CCI_PMU`, `DEBUG_INFO` |
| Filesystems and character sets | 13 | 6 | 0 | `F2FS_FS`, `SQUASHFS`, `ISO9660_FS` |
| Bus and peripheral controllers (I2C, SPI, PCI, PTP, PPS) | 16 | 1 | 0 | `I2C_QUP`, `SPI_QUP`, `PTP_1588_CLOCK` |
| LEDs | 13 | 1 | 1 | `LEDS_AW2013`, `LEDS_CLASS_FLASH`, `LEDS_IS31FL319X` |
| Power, battery and charger | 9 | 4 | 1 | `BATTERY_MAX17042`, `BATTERY_PM8916_BMS_VM`, `BATTERY_RT5033` |
| Terminals and serial | 13 | 0 | 0 | `ACCESSIBILITY`, `NULL_TTY`, `SPEAKUP` |
| Frequency and idle governors | 1 | 8 | 0 | `DEVFREQ_GOV_PASSIVE`, `CPU_FREQ_GOV_CONSERVATIVE`, `CPU_FREQ_GOV_ONDEMAND` |
| Kernel core and memory | 5 | 1 | 0 | `ANDROID_BINDER_IPC`, `DMABUF_HEAPS`, `DMABUF_HEAPS_CMA` |
| NFC | 6 | 0 | 0 | `NFC`, `NFC_NCI`, `NFC_NXP_NCI` |
| Compression | 6 | 0 | 0 | `XZ_DEC_X86`, `XZ_DEC_POWERPC`, `XZ_DEC_SPARC` |
| Virtualization | 3 | 0 | 0 | `KVM`, `VIRTUALIZATION`, `VIRTIO_MENU` |

The list also sets `CONFIG_DEFAULT_TCP_CONG` to `"bbr"`.

The list sets these `y` (built in) options for board functions:

- `LEDS_GPIO`, for the board LEDs
- `USB_CHIPIDEA`, `USB_CHIPIDEA_MSM` and `PHY_QCOM_USB_HS`, for the USB controller and PHY
- `HWSPINLOCK_QCOM`, for the SMEM lock
- `QRTR` and `QCOM_QMI_HELPERS`, for the Wi-Fi and modem QMI services
- `NVMEM_QCOM_QFPROM`, for the fuse driver

The build applies the minimal list first, then the `KERNEL_OPTIONS` file if you set one, then the feature blocks. A later pass overrides an earlier one. A feature block sets the options its feature needs. For example, `WIFI="yes"` sets the Wi-Fi options. To keep an option that the list turns off, set it in the `KERNEL_OPTIONS` file.

If the device does not boot, or the USB gadget or Wi-Fi does not work, check these options first.

## Root filesystem options

- `ROOT_FS="ext4"` turns on `CONFIG_EXT4_FS`.
- `ROOT_FS="btrfs"` turns on `CONFIG_BTRFS_FS` and the compression codecs: zlib, lzo and zstd.
- `ROOT_FS="xfs"` turns on `CONFIG_XFS_FS`.

## Patches

The patch files are in `device/kernel/patches/linux/`. Each patch has a switch. The patches apply in this order:

| Switch | Patch | Effect |
|---|---|---|
| `PATCH_BBR` | `0001-tcp-bbr3-initial-import.patch` | Adds BBR v3 congestion control. BBR is the default. |
| `PATCH_LE9UO` | `0001-le9uo.patch` | Protects anonymous and clean file pages in memory. Adds the `vm.anon_min_ratio` and `vm.clean_low_ratio` sysctls. |
| `PATCH_ZSTD` | `0001-zstd-cachyos.patch` | Adds a newer zstd library. |
| `PATCH_CPR` | `0001-cpr.patch` | Adds core power reduction for MSM8916. Sets the CPU voltage for each frequency. This patch is experimental. |
| `PATCH_SMSM` | `0001-smsm-skip-empty-mboxes.patch` | Skips empty mailbox entries in the SMSM driver. This removes a boot message. |

The CPR patch adds the 1094400, 1152000 and 1209600 kHz steps. Sustained operation at these steps is not guaranteed. When the SoC temperature reaches a trip point, the thermal framework lowers the maximum CPU frequency (thermal throttling). On the test device, forcing 1209600 kHz under full load of all four cores lowered the clock to 400000 to 800000 kHz. This took less than a minute.

Each patch file has a SHA-256 in `device/kernel/patches/README.md`. Check a patch against that file before you change it.

## Device tree trimming

`TRIM_DTB="yes"` deletes the device tree nodes listed in `device/board/uz801v3/uz801v3-kernel-trim.dtsi`. Step 21 appends the list to `msm8916-yiming-uz801v3.dts` before the kernel builds. The list uses `/delete-node/`. A deleted node is absent from the built device tree, so no driver binds to it.

With the trimmed device tree, the usable memory rises to 476 MB. With `TRIM_DTB="no"`, it is 317 MB. The trim removes the reserved memory nodes, so the kernel can use that memory.

### Deleted nodes

| Group | Nodes |
|---|---|
| Reserved memory | `mba_mem`, `mpss_mem`, `rfsa@867e0000`, `rmtfs@86700000`, `venus_mem`, `reserved@86680000` |
| Audio | `lpass`, `lpass_codec`, `sound`, `pm8916_codec` |
| Camera | `camss`, `cci`, `camera-thermal` (thermal zone) |
| Graphics and video | `gpu`, `gpu_iommu`, `mdss`, `venus`, `gpu-thermal` (thermal zone) |
| Modem | `mpss`, `hexagon_smsm`, `smp2p-hexagon`, `modem-thermal` (thermal zone) |
| CoreSight debug | `cti0`, `cti1`, `cti12`, `cti13`, `cti14`, `cti15`, `debug0`, `debug1`, `debug2`, `debug3`, `etf`, `etm0`, `etm1`, `etm2`, `etm3`, `etr`, `funnel0`, `funnel1`, `replicator`, `stm`, `tpiu` |
| Bus fabric | `bimc`, `pcnoc`, `snoc`, `apps_iommu` |
| Serial and bus controllers | `blsp_i2c1` to `blsp_i2c6`, `blsp_spi1` to `blsp_spi6`, `blsp_uart1` |
| SD card | `sdhc_2` |
| PMIC functions | `pm8916_bms`, `pm8916_charger`, `pm8916_resin`, `pm8916_pwm`, `pm8916_vib` |

### Nodes kept by a feature

Step 21 leaves these lines out of the appended list:

| Setting | Nodes kept |
|---|---|
| `MODEM="yes"` | `mba_mem`, `mpss_mem`, `rfsa@`, `rmtfs@`, `smp2p-hexagon`, `hexagon_smsm`, `mpss` |
| `BLUETOOTH="yes"` | `wcnss_bt` |
| `KERNEL_DEBUG="yes"` | `sram@290000` |

### With `TRIM_DTB="no"`

The build keeps every node. It sets `gpu`, `mdss` and `venus` to `status = "disabled"`. It disables `mpss` when `MODEM` is `no`, and `wcnss_bt` when `BLUETOOTH` is `no`. Other nodes keep their status from the upstream device tree.

### Change the list

To keep a node, delete its line from the trim file, or add its name to the filter in `lib/steps/21-build-kernel.sh`. Then run `./build.sh --only-kernel`.

Check that the kernel boots after each change. A deleted node can break a driver that needs it.

## Build only the kernel

To build the kernel and its packages without the rest of the image, use `--only-kernel`:

```sh
sudo sh build.sh --only-kernel
```

The output is two `.deb` files in `work/files/`. To install them on the device, see [kernel update](kernel-update.md).

## Change the kernel

To change the kernel, edit the option lists or the patches. Then rebuild the kernel with `--from 21`. Step 21 starts from a fresh source tree each time, so earlier edits to the source do not carry over.
