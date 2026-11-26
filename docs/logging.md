# Logging

Logging settings come from `config.env` and `device/image/templates/logging/`.

Step 62 writes `/etc/systemd/journald.conf.d/zz-logging.conf`. This drop-in overrides the `Storage=none` line in the base `journald.conf`.

| Setting | Values |
|---|---|
| `LOG_STORAGE` | `disk` keeps logs in `/var/log/journal`. `ram` keeps them in memory only. `none` keeps no logs. |
| `LOG_LEVEL` | `full` keeps debug messages. `normal` keeps info and higher. `minimal` keeps warnings and higher. `none` keeps only emergency messages. |
| `LOG_MAX_SIZE` | Maximum size of the stored journal on disk (`SystemMaxUse`) and in memory (`RuntimeMaxUse`). |
| `LOG_ARCHIVE` | `yes` (default) starts a new journal file each day (`MaxFileSec=1day`), so each day is kept as its own archived file. A daily timer, `journal-archive.timer`, copies each archived file to `/var/backups/logs` as a gzip file (`.gz`). `no` sets `MaxFileSec=infinity` and adds no timer. Files rotate only at the size limit. |
| `LOG_ARCHIVE_COUNT` | Number of journal files to keep (`SystemMaxFiles` and `RuntimeMaxFiles`). The oldest files are deleted first. Default `30`. Must be a whole number of 1 or more. |

Other logging settings:

- `ForwardToSyslog=no` in `journald.conf`.
- `Compress=yes` in `journald.conf`.
- `LOG_FORWARD="yes"` starts `log-forward.service`. It sends the journal over TCP to `LOG_FORWARD_TARGET`.
- `DEBUG_SERVICES="yes"` sets the systemd log level to debug in `/etc/systemd/system.conf.d/zz-debug.conf`.
