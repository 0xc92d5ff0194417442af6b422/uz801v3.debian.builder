#!/bin/sh -e

. ./lib/steps/common.sh

TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

mkdir -p work/files

# GPT GUIDs are written in upper case hex, so the partition IDs are converted.
ROOT_GPT_UUID=$(printf '%s' "${ROOT_PARTUUID}" | tr a-f A-F)
BOOT_GPT_UUID=$(printf '%s' "${BOOT_PARTUUID}" | tr a-f A-F)
export ROOT_GPT_UUID BOOT_GPT_UUID
# The partition table comes from the sfdisk template in device/board.
render device/board/"${BOARD}"/"${BOARD}".sfdisk.in "${TMPDIR}"/gpt.sfdisk ROOT_GPT_UUID BOOT_GPT_UUID
truncate -s 179323904 "${TMPDIR}"/gpt.img
sfdisk "${TMPDIR}"/gpt.img < "${TMPDIR}"/gpt.sfdisk

# The GPT copies go into one file. The first copy holds the headers. The last copy holds the backup table at the end of the disk.
dd if="${TMPDIR}"/gpt.img of=work/files/gpt_both0.bin bs=512 count=34
dd if="${TMPDIR}"/gpt.img bs=512 skip=2 count=32 >> work/files/gpt_both0.bin
dd if="${TMPDIR}"/gpt.img bs=512 skip=350241 >> work/files/gpt_both0.bin
