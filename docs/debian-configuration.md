# Debian configuration

Steps 50 to 71 and the script `lib/steps/chroot/setup-base-system.sh` change the Debian root filesystem.

Files in `device/image/overlay/` are copied into the image unchanged. Files in `device/image/templates/` are rendered first. The build replaces their placeholders with values from `config.env`.

- [Packages](debian-packages.md): packages installed and removed in the base system.
- [Hardening](hardening.md): accounts, login limits, sudo, kernel settings and module blocks.
- [SSH](ssh.md): sshd and ssh client settings.
- [Firewall and network](firewall-and-network.md): iptables rules, network files, DNS and time.
- [Logging](logging.md): journal storage, level and size.
- [Services](services.md): enabled and masked units, and units from the overlay and templates.
- [Watchdog](watchdog.md): the watchdog daemon.
- [Scripts](scripts.md): helper scripts and how to add a unit or a script.
