#!/bin/sh -e

if [ "${USB_GADGET}" != yes ]; then
    exit 0
fi

# libusbgx and gt are cross-built for arm64. Output goes to work/dist, which step 90 copies into the image.
SRCDIR=$(pwd)/work/src

rm -f "${CHROOT}"/etc/resolv.conf
cp -L /etc/resolv.conf "${CHROOT}"/etc/resolv.conf

chroot "${CHROOT}" qemu-aarch64-static /bin/sh \
    -c " apt-get update; apt-get install --no-install-recommends --no-install-suggests libconfig-dev -y"

autoreconf -i work/src/libusbgx

mkdir -p work/build
(
cd work/build
PKG_CONFIG_PATH=${CHROOT}/usr/lib/aarch64-linux-gnu/pkgconfig \
    "${SRCDIR}"/libusbgx/configure \
        --host aarch64-linux-gnu \
        --prefix=/usr \
        --with-sysroot="${CHROOT}"
)
make -C work/build DESTDIR="${PWD}"/work/dist CFLAGS="--sysroot=${CHROOT}" install

# The pkg-config files record the build prefix. It is changed so the gt build finds libusbgx in work/dist.
sed -i "s#^prefix=.*#prefix=${PWD}/work/dist/usr#" work/dist/usr/lib/pkgconfig/*.pc

rm -rf work/build/*
PKG_CONFIG_PATH=${PWD}/work/dist/usr/lib/pkgconfig:${CHROOT}/usr/lib/pkgconfig:${CHROOT}/usr/lib/aarch64-linux-gnu/pkgconfig \
    cmake -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
        -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
        "-DCMAKE_C_FLAGS=-I${PWD}/work/dist/usr/include -L${PWD}/work/dist/usr/lib" \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
        -DCMAKE_SYSROOT="${CHROOT}" \
        -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
        -S "${SRCDIR}"/gt/source \
        -B work/build

make -C work/build DESTDIR="${PWD}"/work/dist install

rm -rf work/dist/usr/share work/dist/usr/lib/cmake work/dist/usr/lib/pkgconfig \
    work/dist/usr/lib/*a work/dist/usr/bin/ga* work/dist/usr/bin/s* work/dist/usr/include

# A build resumed at step 71 or 72 archives this chroot again. The build-only changes must not reach the image.
chroot "${CHROOT}" qemu-aarch64-static /bin/sh -c "apt-get purge -y libconfig-dev && apt-get clean"
rm -rf "${CHROOT}"/var/lib/apt/lists/*
ln -sf ../run/systemd/resolve/stub-resolv.conf "${CHROOT}"/etc/resolv.conf

mkdir -p work/dist/etc/gt/templates
cp device/image/templates/gadget/schemes/*.scheme work/dist/etc/gt/templates
