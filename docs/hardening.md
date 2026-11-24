# Hardening

These settings limit accounts, login, sudo, the kernel and the network stack. They come from the files in `device/image/overlay/hardening/`, from `lib/steps/62-install-hardening-files.sh` and from the module blocks in `device/image/overlay/modprobe.d/zz-custom.conf`.

## Accounts and login

- The root account is locked.
- The account in `ADMIN_USER` is the only login account. It joins the groups `SSH_GROUP` and `WHEEL_GROUP`. Its home directory has mode `0700`.
- Members of `WHEEL_GROUP` can run any command with sudo.
- New accounts get `/bin/false` as their shell (`/etc/default/useradd` and `/etc/adduser.conf`).
- The file `/etc/securetty` is empty. Root cannot log in on a local terminal.
- `/etc/cron.allow` and `/etc/at.allow` list only `root`.
- `/etc/profile` and `/etc/bash.bashrc` set `umask 0077`. New files are private by default.

### Passwords and failed logins

| Setting | File | Value |
|---|---|---|
| Password rules | `/etc/security/pwquality.conf` | At least 4 character classes, 8 characters changed from the old password, dictionary check. Also applies to root. |
| Password history | `pam.d/common-password` | The last 24 passwords cannot be reused. |
| Password hash | `pam.d/common-password` | yescrypt, 11 rounds. |
| Failed logins | `/etc/security/faillock.conf` | Account locks after 5 failures within 900 seconds, for 600 seconds. Also applies to root. |
| Login delay | `pam.d/login` | 4 seconds after a failed login. |
| Process limits | `/etc/security/limits.conf` | 10 logins per user. Core dumps are off. Process limits are 512 soft and 1024 hard. |

### Sessions

- `logind` locks the screen after 15 minutes of idle time. It ends idle sessions after 900 seconds. It stops user processes when the session ends.
- `/etc/default/useradd` sets `INACTIVE=30`. An account is disabled 30 days after its password expires.

### sudo

The files in `/etc/sudoers.d/` set these rules:

| File | Rule |
|---|---|
| `011_use_pty` | Runs commands in a pseudo terminal. |
| `012_logfile` | Writes sudo events to `/var/log/sudo.log`. Removed when `LOG_SUDO="no"`. |
| `013_pwfeedback` | Does not show an asterisk for each typed character at the password prompt. |
| `014_visiblepw` | Refuses to run when the terminal would show the password. |
| `015_passwdtimeout` | Password prompt times out after 1 minute. |
| `016_timestamptimeout` | A sudo session lasts 5 minutes after the last command. |
| `017_timestamptype` | The sudo session belongs to the terminal. |

The `wheel` rule is in `/etc/sudoers.d/wheel`. The build sets its mode to `0440`.
## Kernel settings at runtime

The files in `/etc/sysctl.d/` set these values. The build copies all of them, except `zz-le9uo.conf`. Step 62 removes that file unless `PATCH_LE9UO="yes"` and the kernel is built from source.

| File | Main settings |
|---|---|
| `zz-main-hardening.conf` | IPv4 redirects and source routing are off. Reverse path filter is on. SYN cookies are on. IP forwarding is off. IPv6 is disabled. `kernel.kptr_restrict = 2` and `kernel.dmesg_restrict = 1` hide kernel addresses and logs from users. `kernel.panic_on_oops = 1` reboots after 60 seconds on an oops. Core dumps are off. User namespaces are off. `kernel.yama.ptrace_scope = 2` restricts debugging. |
| `zz-net-buffers.conf` | BBR congestion control with the `fq` queue. Larger socket buffers. TCP Fast Open is on. |
| `zz-dirty-pages.conf` | Writeback starts at 5 percent of memory. Writes block at 10 percent. |
| `zz-zram-swap.conf` | `vm.swappiness = 100` and `vm.min_free_kbytes = 16384`. |
| `zz-printk.conf` | Sets the console log level. |
| `zz-le9uo.conf` | Protects 15 percent of memory for anonymous pages. Only with the LE9UO patch. |

`thp-disable.service` turns off transparent huge pages at boot.
## Kernel modules

`/etc/modprobe.d/zz-custom.conf` blocks modules at run time. Each blocked module runs `/bin/false` on install and is blacklisted.

The kernel build also turns off most of these modules. `device/kernel/blocked-modules.txt` sets the matching `CONFIG_*` options to `is not set`, on every build. The build then does not compile them. Some names in the file, such as `decnet` and `ipx`, have no option in Linux 6.12, so only the blocklist applies to them.

- The file in the overlay blocks drivers and filesystems that this board does not use. Examples are `cifs`, `cdrom`, `cramfs` and several framebuffer and video drivers.
- Step 62 adds blocks for features that are off:

| Setting | Modules blocked |
|---|---|
| `BLUETOOTH="no"` | `bluetooth`, `bnep`, `btbcm`, `btqca`, `btqcomsmd`, `btusb`, `hci_uart`, `hidp`, `rfcomm`, `net-pf-31` |
| `MODEM="no"` | `qcom_bam_dmux`, `qcom_q6v5`, `qcom_q6v5_mss` |
| `WIFI="no"` | `wcn36xx`, `mac80211`, `cfg80211` |
| `USB_GADGET="yes"` | `rndis_host`, `cdc_ether`, `cdc_mbim`, `cdc_ncm`, `usbnet`, `usb-storage`, `usbkbd`, `usbmouse`, `usb-midi` |
