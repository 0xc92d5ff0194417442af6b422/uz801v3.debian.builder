# Update the kernel on the device

## 1. Build the kernel package

From the repository root, run this command on the build machine:

```sh
sudo sh build.sh --only-kernel
```

The build creates these files:

```
work/files/linux-image-<KVER>-uz801v3_<KVER>-1_arm64.deb
work/files/uz801-kernel-tools_1.0-1_arm64.deb
```

`<KVER>` is the kernel version, for example `6.12.118-msm8916`. Copy both files to the device.

This mode builds only the kernel. It does not need the Wi-Fi and SSH settings.

## 2. Install the package on the device

```sh
dpkg -i uz801-kernel-tools_1.0-1_arm64.deb
dpkg -i linux-image-<KVER>-uz801v3_<KVER>-1_arm64.deb
```

The package does this:

- It copies the kernel to `/boot/vmlinuz-<KVER>`.
- It copies the board DTB to `/boot/dtbs/qcom/<DTB>-<KVER>.dtb`.
- It copies the modules to `/usr/lib/modules/<KVER>`.
- The `uz801-kernel-tools` package installs the helper `/usr/sbin/uz801-kernel`. Install it once. Every kernel package uses it.
- It runs `depmod` for the new kernel.

The boot entry does not change. The device still boots the kernel that ran before.

## 3. Check the installed kernels

```sh
uz801-kernel status
```

This shows the current boot entry and the installed kernels.

## 4. Test the new kernel once

The test uses `kexec`. It starts the new kernel from the running system. The boot entry does not change.

Set `KEXEC="yes"` in `config.env` before you build. This setting turns on `CONFIG_KEXEC` and `CONFIG_SUSPEND`. With `KEXEC="no"`, `kexec` does not work.

If `kexec-tools` is missing, install it:

```sh
apt install kexec-tools
```

Load the new kernel and restart into it:

```sh
kexec -l /boot/vmlinuz-<KVER> --dtb=/boot/dtbs/qcom/<DTB>-<KVER>.dtb --reuse-cmdline
systemctl kexec
```

Your SSH session ends. Reconnect over USB (`192.168.254.1`) or Wi-Fi.

Check the new kernel:

```sh
uname -r
systemctl --failed
dmesg --level=err,warn | head -40
```

## 5a. The new kernel works

Make it the default:

```sh
uz801-kernel set <KVER>
```

The next normal reboot uses the new kernel. The helper saves the old boot entry first.

## 5b. The new kernel does not come back

Unplug the power and plug it in again. The boot entry did not change, so the device starts the old kernel.

## Undo a default change

```sh
uz801-kernel revert
```

This restores the boot entry that `uz801-kernel set` saved. Reboot to use it.

## Limits

- `uz801-kernel` does not run `kexec` for you. Run the `kexec` commands by hand.
- `kexec` is not tested on this SoC. If it fails, check if it needs an uncompressed `Image` file.
- The USB gadget and Wi-Fi can fail to come back after `kexec`. If they fail, follow step 5b.
- If `kexec -l` fails, nothing changes on the device.
- Old module folders stay in `/usr/lib/modules` after an update. Remove them only after the new kernel works. The helper does not remove them.
- The helper does not select a kernel at boot. The device has no boot menu.
