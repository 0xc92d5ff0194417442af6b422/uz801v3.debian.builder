#!/bin/sh -e

# Only a kernel-only build packages the kernel here. A full build installs it into the rootfs in step 64.
if [ "${ONLY_KERNEL}" != yes ]; then
    exit 0
fi

KVER=$(cat work/files/kernel/kernel-release)
PKG=linux-image-${KVER}-uz801v3
DEB=work/files/${PKG}_${KVER}-1_arm64.deb
TOOLS_PKG=uz801-kernel-tools
TOOLS_DEB=work/files/${TOOLS_PKG}_1.0-1_arm64.deb
DTB_BASE=${DTB_NAME%.dtb}
STAGE=$(mktemp -d)
TOOLS=$(mktemp -d)
trap 'rm -rf "${STAGE}" "${TOOLS}"' EXIT

mkdir -p "${STAGE}/DEBIAN" "${STAGE}/boot/dtbs/qcom" "${STAGE}/usr/lib/modules"
cp work/files/kernel/rootfs/boot/vmlinuz "${STAGE}/boot/vmlinuz-${KVER}"
cp work/files/kernel/rootfs/boot/dtbs/qcom/"${DTB_NAME}" "${STAGE}/boot/dtbs/qcom/${DTB_BASE}-${KVER}.dtb"
cp -a work/files/kernel/rootfs/lib/modules/"${KVER}" "${STAGE}/usr/lib/modules/"

cat > "${STAGE}/DEBIAN/control" <<CONTROL
Package: ${PKG}
Version: ${KVER}-1
Architecture: arm64
Maintainer: OpenStick Builder <noreply@localhost>
Section: kernel
Priority: optional
Description: Linux kernel ${KVER} for the UZ801 v3
 Installs the kernel, its DTB and modules next to the running kernel.
 Switch with: uz801-kernel set ${KVER}
CONTROL

cat > "${STAGE}/DEBIAN/postinst" <<POSTINST
#!/bin/sh -e
if [ "\$1" = configure ]; then
    depmod -a ${KVER}
fi
POSTINST
chmod 0755 "${STAGE}/DEBIAN/postinst"

dpkg-deb --root-owner-group --build "${STAGE}" "${DEB}" >/dev/null
echo "kernel package: ${DEB}"

# A second package installs uz801-kernel, the tool that picks the boot kernel.
mkdir -p "${TOOLS}/DEBIAN" "${TOOLS}/usr/sbin"
install -m 0755 device/image/overlay/usr/sbin/uz801-kernel "${TOOLS}/usr/sbin/uz801-kernel"
cat > "${TOOLS}/DEBIAN/control" <<CONTROL
Package: ${TOOLS_PKG}
Version: 1.0-1
Architecture: arm64
Maintainer: OpenStick Builder <noreply@localhost>
Section: admin
Priority: optional
Description: Boot helper for the UZ801 v3 kernels
 Lists, sets and reverts the boot kernel: uz801-kernel status|set KVER|revert
CONTROL
dpkg-deb --root-owner-group --build "${TOOLS}" "${TOOLS_DEB}" >/dev/null
echo "tools package: ${TOOLS_DEB}"
