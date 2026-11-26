# SSH

The SSH server and client settings come from `device/image/templates/ssh/` and `lib/steps/70-configure-ssh.sh`.

The template `device/image/templates/ssh/sshd_config.in` sets these rules:

| Setting | Value | Effect |
|---|---|---|
| `Port` | `SSH_PORT` | Port that the server listens on. |
| `PermitRootLogin` | `no` | Root cannot log in over SSH. |
| `PasswordAuthentication` | `no` | Only keys work. |
| `AuthenticationMethods` | `publickey` | A key is required. |
| `PubkeyAcceptedAlgorithms` | `ssh-ed25519` | Only Ed25519 keys are accepted. |
| `AllowUsers` | `ADMIN_USER` | Only this account can log in. |
| `AllowGroups` | `SSH_GROUP` | The account must be in this group. |
| `MaxAuthTries` | `3` | Three failed attempts per connection. |
| `LoginGraceTime` | `30` | 30 seconds to log in. |
| `AllowTCPForwarding`, `AllowAgentForwarding`, `X11Forwarding` | `no` | No tunnels, agent forwarding or X11. |
| `Ciphers`, `MACs`, `KexAlgorithms` | Fixed in the template. | Cipher, MAC and key exchange lists. They are not set in `config.env`. |

The client file `/etc/ssh/ssh_config` has its cipher, MAC and key exchange lists fixed in the template.

Step 70 writes the public keys from `ADMIN_SSH_KEYS` to `~admin/.ssh/authorized_keys`.

The image has no SSH host keys. Each device creates its own Ed25519 key on first boot (`ssh-hostkeys.service`).

## Limit the source addresses

When `SSH_ALLOW_FROM` lists addresses, step 70 adds a `Match` block to `sshd_config`. The block denies login from every address that the list does not include. Each entry is an IP address or a CIDR subnet, and the entries are separated by spaces.
