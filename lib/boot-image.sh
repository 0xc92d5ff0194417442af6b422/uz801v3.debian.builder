
# Rebuilds boot.bin from the last rootfs.tgz. Use it to test a new device tree without a full build.
build_boot_only() {
[ -f work/rootfs.tgz ] || fail "--only-boot needs work/rootfs.tgz: run build.sh first"
[ -f "${ONLY_BOOT_DTB}" ] || fail "--only-boot file not found: ${ONLY_BOOT_DTB}"
BOOT_WORK=$(mktemp -d)
mkdir -p "${BOOT_WORK}/boot/dtbs/qcom"
tar xzf work/rootfs.tgz -C "${BOOT_WORK}" ./boot --exclude='./boot/linux.efi' --exclude='./boot/dtbs/*'
# A .dts file is compiled. Any other file is copied as a .dtb.
case "${ONLY_BOOT_DTB}" in
    *.dts) compile_dtb "${ONLY_BOOT_DTB}" "${BOOT_WORK}/boot/dtbs/qcom/${DTB_NAME}" ;;
    *) cp "${ONLY_BOOT_DTB}" "${BOOT_WORK}/boot/dtbs/qcom/${DTB_NAME}" ;;
esac
make_boot_image "${BOOT_WORK}/boot"
rm -rf "${BOOT_WORK}"
msg OK "built work/files/boot.bin with ${ONLY_BOOT_DTB}"
}
