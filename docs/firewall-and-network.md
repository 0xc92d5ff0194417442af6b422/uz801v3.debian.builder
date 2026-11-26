# Firewall and network

The firewall and network files come from `device/image/templates/firewall/`, `device/image/templates/network/` and `lib/steps/63-configure-network-and-firewall.sh`.

## Firewall

`/etc/iptables/rules.v4` and `/etc/iptables/rules.v6` are loaded at boot by `firewall.service`. The IPv6 rules drop all traffic.

The IPv4 rules set the default policy to `DROP` for input and forward. They accept:

- traffic on the loopback interface
- replies to connections that the device started
- SSH on `SSH_PORT`, from `wlan0` and `usb0`. A source address that opens more than 10 new SSH connections per minute is dropped after a burst of 5. The rule uses the `hashlimit` match, so the kernel needs `xt_hashlimit`.
- DHCP replies on `wlan0`
- ping requests from `wlan0` and `usb0`

`FIREWALL_RULES_V4_EXTRA` and `FIREWALL_RULES_V6_EXTRA` add rules before the `COMMIT` line.

Step 63 checks the IPv4 rules with `iptables-restore --test`. The check is skipped with a warning when the build host has no netfilter access.
## Network

- `systemd-networkd` configures `wlan0` (`/etc/systemd/network/wlan0.network`).
- The file `usb0.network` is added only when `USB_GADGET` is `yes` and the mode is `rndis`, `ecm`, `cdc-ecm` or `acm-ecm`.
- `/etc/resolv.conf` points to the `systemd-resolved` stub. `DNS_SERVER` sets the DNS server.
- `systemd-timesyncd` uses the servers in `NTP_SERVERS`. The default is `pool.ntp.org`.
- The Wi-Fi file `/etc/wpa_supplicant/wpa_supplicant-wlan0.conf` has mode `0600` because it holds the password.
- `wifi-powersave-off.service` turns off Wi-Fi power save on `wlan0` at boot. It is removed when `WIFI="no"`.
- `wcnss-mac-address.service` writes a random MAC address for `wlan0` on the first boot. The address is stored in `/usr/lib/firmware/wcnss_mac_addr`.
