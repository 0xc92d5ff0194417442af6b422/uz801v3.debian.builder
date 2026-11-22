# Build

## Requirements

- A Linux host with root access. The build uses `chroot`, `mount` and loop devices.
- Network access for the first run. Later runs reuse the downloads in `work/`.
- At least 10 GB of free disk space. The kernel source, the build cache and the root filesystem image need it.
- The host packages from step 10. The build installs them with `apt`, so you need `apt` and root.

The build targets Debian. Other distributions need the same tools.

## Run the build

From the repository root:

```sh
sudo sh build.sh
```

The build reads `config.env` from the repository root. To use another file, pass `--config`:

```sh
sudo sh build.sh --config my.env
```

The terminal shows one line per step, a progress bar and the time each step took. The full output goes to `work/files/build.log`.

## Switches

| Switch | Effect |
|---|---|
| `--config FILE` | Read values from FILE instead of `config.env`. |
| `--from STEP` | Start at STEP and run every later step. STEP is a number, such as `64`, or a full name, such as `64-install-kernel-and-dtb`. |
| `--only STEP` | Run only STEP. Step 10 runs first. Do not combine it with `--from`. |
| `--only-kernel` | Build only the kernel and its `.deb` packages. Needs `KERNEL_SOURCE=build`. |
| `--only-boot FILE` | Rebuild `work/files/boot.bin` with the device tree in FILE (`.dts` or `.dtb`). Needs a full build first. |
| `--use-base-cache` | Restore the saved base rootfs. Debootstrap does not run again. |
| `--clean` | Delete generated files, then stop. Run with `sudo`. |
| `--fresh` | Delete generated files, then build from the start. Run with `sudo`. |
| `--help`, `-h` | Print the usage line and exit. |

Do not use `--clean` or `--fresh` with `--from`.

An unknown switch prints `unknown argument: NAME` and the usage line. The build then exits with status 2.

## Steps

Each step is a file in `lib/steps/`. The build runs the steps in filename order.

| Step | Name | What it does |
|---|---|---|
| 10 | install-build-deps | Installs the host packages and, for a built kernel, the kernel tools. Runs first on every build, including `--from` runs. |
| 15 | fetch-sources | Fetches the source submodules into `work/src/`. |
| 20 | build-hyp-aboot | Builds the hypervisor stub (qhypstub) and the lk2nd bootloader. |
| 21 | build-kernel | Downloads the kernel and the postmarketOS config. Applies the patches. Builds the kernel and the modules. |
| 22 | package-kernel-deb | Packages the kernel as `.deb` files. Runs only with `--only-kernel`. |
| 30 | make-gpt-image | Writes the partition table to `work/files/gpt_both0.bin`. |
| 40 | extract-firmware | Downloads the Qualcomm bootloader zip. Extracts `rpm.mbn`, `sbl1.mbn` and `tz.mbn`. |
| 50 | bootstrap-rootfs | Runs debootstrap and sets up the Debian chroot. Saves a base tarball for `--use-base-cache`. |
| 60 | configure-system | Sets the host name, the machine ID and `fstab`. |
| 61 | install-systemd-units | Copies the system units and helper scripts. Renders the templates. |
| 62 | install-hardening-files | Installs the sudo, cron, sysctl and modprobe rules and the logging values. |
| 63 | configure-network-and-firewall | Writes the Wi-Fi and USB network files and the firewall rules. Checks the rules. The check needs netfilter access. |
| 64 | install-kernel-and-dtb | Installs the kernel, the device tree and `extlinux.conf`. Sets the kernel command line. |
| 65 | install-wifi-firmware | Copies the board firmware. Writes the fixed Wi-Fi MAC from `WIFI_MAC`. |
| 70 | configure-ssh | Writes the SSH values, the admin keys and the host key check. |
| 71 | clean-rootfs | Removes logs, caches and documentation from the chroot. |
| 72 | archive-rootfs | Writes `work/rootfs.tgz`. |
| 80 | build-gadget-tools | Runs only with `USB_GADGET="yes"`. Cross-builds libusbgx and the gadget tools (gt). |
| 90 | build-images | Writes `work/files/rootfs.bin` and `work/files/boot.bin`. |

After the last step, the build writes `work/files/device-info.env` and prints the admin password.

## Outputs

The build writes all outputs to `work/files/`:

| File | Use |
|---|---|
| `gpt_both0.bin` | Partition table. |
| `aboot.mbn`, `hyp.mbn` | Bootloader images. |
| `rpm.mbn`, `sbl1.mbn`, `tz.mbn` | Qualcomm firmware. |
| `boot.bin` | Boot partition image. |
| `rootfs.bin` | Root partition image. |
| `device-info.env` | Host name, admin account, Wi-Fi and partition IDs. Holds passwords. Mode 600. |
| `build.log` | Full build output. Mode 600. |
| `*.deb` | Kernel packages, built with `--only-kernel`. |

## Clean and resume

If a build stops part way, you can resume it from the failed step:

```sh
sudo sh build.sh --from 64
```

A resumed build keeps the log and reuses the values from the first run. For any value that `config.env` leaves empty, the build reads the admin password and the host name from `device-info.env`.

Use `--clean` to delete the generated files in `work/`, such as the kernel cache, the root filesystem and the images. It keeps `config.env` and the downloads. Use `--fresh` to clean and then build again.

## Logs

Each run appends to `work/files/build.log`. A new build starts with an empty log. A build run with `--from` or `--only` adds to the existing log.

If a step fails, the last lines of the log show the command that failed.
