# Scripts

The image installs these scripts in `/usr/sbin`.

| Script | Used by | What it does |
|---|---|---|
| `apt-security-upgrade.sh` | `apt-security-upgrade.service` | Runs `apt-get update`. Installs upgrades for packages from the security suite (`SECURITY_SUITE`). |
| `zram-swap.sh` | `zram-swap.service` | Starts compressed swap in RAM with `zstd`. The size is `ZRAM_PERCENT` of the total memory. The `stop` action turns the swap off. |
| `wcnss-mac-address.sh` | `wcnss-mac-address.service` | Creates a random, locally administered MAC address for `wlan0` and stores it. Runs once. |
| `led-boot.sh` | `led-progress-*.service`, `led-boot-animation.service` | Sets the LEDs for each boot stage. The `animate` action shows the ready signal, or blinks all LEDs when a unit failed. |

The build does not install `uz801-kernel` on the image. Step 22 puts it in the `uz801-kernel-tools` package. The tool lists, sets and reverts the boot kernel.

## Add a unit or a script

1. Put the unit file in `device/image/overlay/system/`, or the script in `device/image/overlay/usr/sbin/`.
2. For a unit, enable it with `ENABLE_SERVICES` in `config.env`. Or add a symlink in step 61.
3. For a script, add its path to the `install` line in `lib/steps/61-install-systemd-units.sh`. The step copies only the scripts that it lists.
4. Run the build from step 61: `./build.sh --from 61`.

Steps 61 to 63 copy the overlay. A change to the overlay has no effect until one of these steps runs again.
