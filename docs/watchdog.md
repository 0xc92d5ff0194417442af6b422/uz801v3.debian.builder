# Watchdog

The watchdog reboots the device when the daemon stops responding.

With `WATCHDOG="yes"`, the build installs the `watchdog` package and enables `watchdog.service`. The config file is `/etc/watchdog.conf`, from `device/image/overlay/watchdog/etc/watchdog.conf`. The file uses the PMIC power-on watchdog at `/dev/watchdog`, with a 60 second timeout and a 10 second interval. The hardware maximum is 127 seconds.

With `WATCHDOG="no"`, the build installs nothing for the watchdog.
