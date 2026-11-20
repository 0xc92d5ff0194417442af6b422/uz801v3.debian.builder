#!/bin/sh -e

# Builds the hypervisor stub and the lk2nd bootloader. The lk2nd change turns on HS200 eMMC support.
make -C work/src/qhypstub CROSS_COMPILE=aarch64-linux-gnu-

grep -qx 'DEFINES += USE_TARGET_HS200_CAPS=1' work/src/lk2nd/project/lk1st-msm8916.mk ||
    echo 'DEFINES += USE_TARGET_HS200_CAPS=1' >> work/src/lk2nd/project/lk1st-msm8916.mk

make -C work/src/lk2nd LK2ND_BUNDLE_DTB="${LK2ND_BUNDLE_DTB}" LK2ND_COMPATIBLE="${BOARD_COMPATIBLE}" \
    TOOLCHAIN_PREFIX=arm-none-eabi- lk1st-msm8916

mkdir -p work/files
# qtestsign adds the test signatures that the boot chain accepts. The results go to work/files.
work/src/qtestsign/qtestsign.py hyp work/src/qhypstub/qhypstub.elf \
    -o work/files/hyp.mbn
work/src/qtestsign/qtestsign.py aboot work/src/lk2nd/build-lk1st-msm8916/emmc_appsboot.mbn \
    -o work/files/aboot.mbn
