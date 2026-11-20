#!/bin/sh -e

FNAME=$(basename "${FW_URL}")
ZIPDIR=${FNAME%.*}
# The zip is kept in work/downloads, so later builds do not fetch it again.
FW_KEPT=work/downloads/${FNAME}

mkdir -p work/files work/downloads

if [ ! -f "${FW_KEPT}" ]; then
    wget --progress=bar:force -O "${FW_KEPT}.part" "${FW_URL}" 2>&4
    mv "${FW_KEPT}.part" "${FW_KEPT}"
else
    echo "using kept copy: ${FW_KEPT}"
fi

# A failed checksum deletes the file, so the next run downloads it again.
if ! echo "${FW_SHA256}  ${FW_KEPT}" | sha256sum -c -; then
    rm -f "${FW_KEPT}"
    echo "checksum failed: removed ${FW_KEPT}" >&2
    exit 1
fi

# Only the three firmware images that the boot chain needs are taken from the zip.
unzip -o -j -d work/files/ "${FW_KEPT}" "${ZIPDIR}"/rpm.mbn "${ZIPDIR}"/sbl1.mbn "${ZIPDIR}"/tz.mbn
