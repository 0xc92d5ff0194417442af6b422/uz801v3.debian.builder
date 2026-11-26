#!/bin/sh -e

# Copies the archived journal files to /var/backups/logs as gzip files and keeps the newest COUNT copies.
# COUNT is set at build time in /etc/default/journal-archive (LOG_ARCHIVE_COUNT).
DEST=/var/backups/logs
COUNT=30
[ -f /etc/default/journal-archive ] && . /etc/default/journal-archive

mkdir -p "${DEST}"
chmod 0700 "${DEST}"

# Archived files end in .journal~. The journal is in /run when LOG_STORAGE is ram.
for dir in /var/log/journal /run/log/journal; do
    [ -d "${dir}" ] || continue
    for f in "${dir}"/*/system@*.journal~; do
        [ -e "${f}" ] || continue
        name=$(basename "${f}")
        [ -e "${DEST}/${name}.gz" ] && continue
        gzip -c "${f}" > "${DEST}/${name}.gz.part"
        touch -r "${f}" "${DEST}/${name}.gz.part"
        chmod 0600 "${DEST}/${name}.gz.part"
        mv "${DEST}/${name}.gz.part" "${DEST}/${name}.gz"
    done
done

# ls -t lists the newest first. Everything after the first COUNT names is removed.
ls -1t "${DEST}" | tail -n +$((COUNT + 1)) | while read -r old; do
    rm -f -- "${DEST}/${old}"
done
