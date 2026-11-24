# Debian packages

The build installs these packages in the root filesystem.

## Packages

Step 50 runs debootstrap to create the base system. Then `setup-base-system.sh` installs these packages:

- `cracklib-runtime`, `libpam-pwquality` and `wamerican`, for password checks
- `iptables`, for the firewall
- `locales` and `tzdata`, for the locale and time zone
- `openssh-server` and `sudo`
- `systemd-resolved` and `systemd-timesyncd`

It also installs the packages in `EXTRA_PACKAGES`. The build adds packages for each enabled feature, for example `bluez` for `BLUETOOTH="yes"` and `wireless-regdb` and `iw` for `WIFI="yes"`.

Apt does not install recommended or suggested packages. Apt refuses insecure repositories and redirects.

After installation, the script makes these changes:

- It removes the default accounts `games`, `news`, `sync`, `uucp`, `list` and `irc`.
- It sets compilers and assemblers (`gcc`, `cc`, `as`, `clang`, `cargo`) to mode `0750`, so only root can run them.
- It removes the setuid and setgid bits from every file, except `sudo`, `passwd`, `unix_chkpwd` and the D-Bus launch helper.
