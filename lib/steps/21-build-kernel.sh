#!/bin/sh -e

. ./lib/steps/common.sh

if [ "${KERNEL_SOURCE}" != build ]; then
    exit 0
fi

# Downloads and ccache live in work/cache. They are kept between builds.
CACHE=$(pwd)/work/cache/kernel
OUT=$(pwd)/work/files/kernel
CROSS_CCACHE="ccache aarch64-linux-gnu-"
CCACHE_DIR=$(pwd)/work/cache/ccache
export CCACHE_DIR
mkdir -p "${CACHE}" "${OUT}"

# The tarball is checked against its SHA512 on every run. A bad copy is downloaded again.
SRC_TAR="${CACHE}/${KERNEL_TAG}.tar.xz"
if [ ! -f "${SRC_TAR}" ] || ! echo "${KERNEL_SRC_SHA512}  ${SRC_TAR}" | sha512sum -c -; then
    rm -f "${SRC_TAR}"
    wget --https-only --tries=5 -O "${SRC_TAR}" "${KERNEL_SRC_URL}"
    echo "${KERNEL_SRC_SHA512}  ${SRC_TAR}" | sha512sum -c -
fi

# The base config comes from a pinned postmarketOS commit, so upstream changes do not alter this build.
PMAPORTS="${CACHE}/pmaports.git"
CONFIG="${CACHE}/config.aarch64"
if [ ! -d "${PMAPORTS}" ]; then
    git init -q --bare "${PMAPORTS}"
fi
if ! git --git-dir="${PMAPORTS}" cat-file -e "${KERNEL_CONFIG_COMMIT}^{commit}" 2>/dev/null; then
    git --git-dir="${PMAPORTS}" fetch -q --depth=1 \
        https://gitlab.postmarketos.org/postmarketOS/pmaports.git "${KERNEL_CONFIG_COMMIT}"
fi
git --git-dir="${PMAPORTS}" show \
    "${KERNEL_CONFIG_COMMIT}:device/testing/linux-postmarketos-qcom-msm8916/config-postmarketos-qcom-msm8916.aarch64" \
    > "${CONFIG}"
echo "${KERNEL_CONFIG_SHA512}  ${CONFIG}" | sha512sum -c -

# The source tree is unpacked fresh for each build, so earlier option edits do not carry over.
SRC="${CACHE}/linux-${KERNEL_TAG}"
rm -rf "${SRC}"
mkdir -p "${SRC}"
tar -xf "${SRC_TAR}" -C "${SRC}" --strip-components=1
cp "${CONFIG}" "${SRC}/.config"

# Edits .config in place. The old line for the option is removed before the new line is added.
replace_config() {
    sed -i "/^# $1 is not set\$/d; /^$1=/d" "${SRC}/.config"
    echo "$2" >> "${SRC}/.config"
}
set_config() { replace_config "$1" "$1=$2"; }
unset_config() { replace_config "$1" "# $1 is not set"; }
# The blocked-modules list is applied first, on every build. The minimal list comes next. A custom KERNEL_OPTIONS file comes last, so it can override both.
KERNEL_OPTION_FILES="device/kernel/blocked-modules.txt"
if [ "${MINIMAL_KERNEL}" = yes ]; then
    KERNEL_OPTION_FILES="${KERNEL_OPTION_FILES} device/kernel/minimal-kernel.txt"
fi
if [ -n "${KERNEL_OPTIONS}" ]; then
    KERNEL_OPTION_FILES="${KERNEL_OPTION_FILES} ${KERNEL_OPTIONS}"
fi
# Carriage returns are removed, so a file with Windows line endings works. A last line without a newline is still read.
for opt_file in ${KERNEL_OPTION_FILES}; do
    tr -d '\r' < "${opt_file}" | while IFS= read -r line || [ -n "${line}" ]; do
        case "${line}" in
            "# CONFIG_"*" is not set")
                name=${line#"# "}
                unset_config "${name% is not set}"
                ;;
            CONFIG_*=*)
                set_config "${line%%=*}" "${line#*=}"
                ;;
        esac
    done
done

# Always on. The CPU power driver (CPR) and BBR depend on these options.
# The image sysctl sets the fq qdisc for BBR, so fq stays on without the minimal list.
set_config CONFIG_SYSCTL y
if [ "${ZRAM}" = yes ]; then
    set_config CONFIG_ZRAM y
else
    unset_config CONFIG_ZRAM
fi
set_config CONFIG_QCOM_CPR y
set_config CONFIG_TCP_CONG_ADVANCED y
set_config CONFIG_TCP_CONG_BBR y
set_config CONFIG_DEFAULT_BBR y
set_config CONFIG_NET_SCH_FQ y
# LED triggers for the LED service. Built in, because writing a trigger name does not load its module.
set_config CONFIG_LEDS_TRIGGER_ACTIVITY y
set_config CONFIG_LEDS_TRIGGER_NETDEV y

# The Wi-Fi and Bluetooth firmware loaders are built as modules.
if [ "${WIFI}" = yes ]; then
    set_config CONFIG_CFG80211 m
    set_config CONFIG_MAC80211 m
    set_config CONFIG_WCN36XX m
    set_config CONFIG_CFG80211_CERTIFICATION_ONUS y
    unset_config CONFIG_CFG80211_REQUIRE_SIGNED_REGDB
else
    unset_config CONFIG_WCN36XX
    unset_config CONFIG_MAC80211
    unset_config CONFIG_CFG80211
fi
if [ "${WIFI}" = yes ] || [ "${BLUETOOTH}" = yes ]; then
    set_config CONFIG_QCOM_WCNSS_PIL m
    set_config CONFIG_QCOM_WCNSS_CTRL m
else
    unset_config CONFIG_QCOM_WCNSS_PIL
    unset_config CONFIG_QCOM_WCNSS_CTRL
fi
if [ "${WIFI}" = yes ] || [ "${BLUETOOTH}" = yes ] || [ "${MODEM}" = yes ]; then
    set_config CONFIG_QCOM_MDT_LOADER m
    set_config CONFIG_QCOM_PIL_INFO m
    set_config CONFIG_QCOM_RPROC_COMMON m
fi
# USB host-side drivers: only needed when the USB port is a host (USB_GADGET=no)
if [ "${USB_GADGET}" = yes ]; then
    unset_config CONFIG_USB_NET_DRIVERS
    unset_config CONFIG_USB_EHCI_HCD
    unset_config CONFIG_USB_EHCI_ROOT_HUB_TT
    unset_config CONFIG_USB_EHCI_TT_NEWSCHED
    unset_config CONFIG_USB_OHCI_LITTLE_ENDIAN
    unset_config CONFIG_USB_CHIPIDEA_HOST
else
    set_config CONFIG_USB_NET_DRIVERS y
    set_config CONFIG_USB_EHCI_HCD y
    set_config CONFIG_USB_EHCI_ROOT_HUB_TT y
    set_config CONFIG_USB_EHCI_TT_NEWSCHED y
    set_config CONFIG_USB_OHCI_LITTLE_ENDIAN y
    set_config CONFIG_USB_CHIPIDEA_HOST y
    # The minimal list turns these off. Host mode needs them for USB Ethernet and USB storage.
    set_config CONFIG_USB_USBNET m
    set_config CONFIG_USB_NET_CDCETHER m
    set_config CONFIG_USB_NET_RNDIS_HOST m
    set_config CONFIG_SCSI y
    set_config CONFIG_USB_STORAGE m
fi
if [ "${BLUETOOTH}" = yes ]; then
    set_config CONFIG_BT m
    set_config CONFIG_BT_QCOMSMD m
    set_config CONFIG_BT_QCA m
    set_config CONFIG_SERIAL_DEV_BUS y
    set_config CONFIG_SERIAL_DEV_CTRL_TTYPORT y
else
    unset_config CONFIG_BT
    unset_config CONFIG_BT_QCOMSMD
    unset_config CONFIG_BT_QCA
    unset_config CONFIG_SERIAL_DEV_BUS
    unset_config CONFIG_SERIAL_DEV_CTRL_TTYPORT
fi
# The image has no display or video. The matching device tree nodes are removed too.
unset_config CONFIG_DRM_MSM
unset_config CONFIG_VIDEO_QCOM_VENUS
if [ "${MODEM}" = yes ]; then
    set_config CONFIG_QRTR y
    set_config CONFIG_QRTR_SMD y
    set_config CONFIG_WWAN y
    set_config CONFIG_QCOM_Q6V5_COMMON m
    set_config CONFIG_QCOM_Q6V5_MSS m
    set_config CONFIG_QCOM_PD_MAPPER m
    set_config CONFIG_QCOM_PDR_HELPERS m
    set_config CONFIG_QCOM_PDR_MSG m
    # Data and control ports for the modem. The minimal list turns them off.
    set_config CONFIG_QCOM_BAM_DMUX m
    set_config CONFIG_RMNET m
    set_config CONFIG_RPMSG_WWAN_CTRL m
else
    unset_config CONFIG_QCOM_Q6V5_MSS
    unset_config CONFIG_WWAN
fi
# Every gadget function is removed first. The chosen USB_GADGET_MODE adds its functions back.
for f in F_ACM F_SERIAL F_OBEX F_NCM F_ECM F_EEM F_RNDIS F_MASS_STORAGE F_FS F_UAC1 F_UAC2 F_MIDI F_MIDI2 F_UVC F_HID F_PRINTER U_SERIAL U_ETHER U_AUDIO; do
    unset_config CONFIG_USB_${f}
done
for f in ACM SERIAL OBEX NCM ECM EEM RNDIS MASS_STORAGE F_FS F_UAC1 F_UAC2 F_MIDI F_MIDI2 F_UVC F_HID F_PRINTER; do
    unset_config CONFIG_USB_CONFIGFS_${f}
done
if [ "${USB_GADGET}" = yes ]; then
    set_config CONFIG_USB_GADGET y
    set_config CONFIG_USB_LIBCOMPOSITE m
    set_config CONFIG_USB_CONFIGFS m
    # Turns on the functions for one gadget mode. Each function is a module, and its configfs link is built in.
    enable_gadget() {
        for fn in $1; do set_config CONFIG_USB_${fn} m; done
        for cf in $2; do set_config CONFIG_USB_CONFIGFS_${cf} y; done
    }
    case "${USB_GADGET_MODE}" in
        rndis) enable_gadget "F_RNDIS U_ETHER" "RNDIS" ;;
        ecm|cdc-ecm) enable_gadget "F_ECM U_ETHER" "ECM" ;;
        acm) enable_gadget "F_ACM U_SERIAL" "ACM" ;;
        acm-ecm) enable_gadget "F_ACM U_SERIAL F_ECM U_ETHER" "ACM ECM" ;;
        mass) enable_gadget "F_MASS_STORAGE" "MASS_STORAGE" ;;
        ffs) enable_gadget "F_FS" "F_FS" ;;
        hid)
            # The HID function needs the HID bus, which minimal-kernel.txt turns off.
            set_config CONFIG_HID_SUPPORT y
            enable_gadget "F_HID" "F_HID"
            ;;
    esac
else
    unset_config CONFIG_USB_GADGET
    unset_config CONFIG_USB_LIBCOMPOSITE
    unset_config CONFIG_USB_CONFIGFS
fi

# Debug options add code and log output. They stay off unless KERNEL_DEBUG=yes.
if [ "${KERNEL_DEBUG}" = yes ]; then
    set_config CONFIG_DEBUG_KERNEL y
    set_config CONFIG_DYNAMIC_DEBUG y
    set_config CONFIG_DEBUG_FS y
    set_config CONFIG_SCHED_DEBUG y
    set_config CONFIG_PRINTK_TIME y
    set_config CONFIG_ELF_CORE y
    set_config CONFIG_IKCONFIG y
    set_config CONFIG_IKCONFIG_PROC y
    set_config CONFIG_DYNAMIC_DEBUG_CORE y
else
    unset_config CONFIG_DEBUG_KERNEL
    unset_config CONFIG_DYNAMIC_DEBUG
    unset_config CONFIG_DEBUG_FS
    unset_config CONFIG_SCHED_DEBUG
    unset_config CONFIG_IKCONFIG
    unset_config CONFIG_IKCONFIG_PROC
    unset_config CONFIG_DYNAMIC_DEBUG_CORE
    # ELF_CORE has no prompt unless EXPERT is set. Without EXPERT the unset is ignored.
    set_config CONFIG_EXPERT y
    unset_config CONFIG_ELF_CORE
fi
# pstore keeps the kernel log in reserved RAM, so it survives a crash. The ramoops node below sets the address.
if [ "${CRASH_CAPTURE}" = yes ]; then
    set_config CONFIG_PSTORE y
    set_config CONFIG_PSTORE_RAM y
    set_config CONFIG_PSTORE_CONSOLE y
else
    unset_config CONFIG_PSTORE_RAM
    unset_config CONFIG_PSTORE_CONSOLE
fi

# kexec needs SUSPEND and KEXEC together. Both are removed when KEXEC is not yes.
if [ "${KEXEC}" = yes ]; then
    set_config CONFIG_SUSPEND y
    set_config CONFIG_KEXEC y
else
    unset_config CONFIG_KEXEC
    unset_config CONFIG_SUSPEND
fi

set_config CONFIG_EXT4_FS y
case "${ROOT_FS}" in
    btrfs)
        set_config CONFIG_BTRFS_FS y
        unset_config CONFIG_XFS_FS
        set_config CONFIG_ZLIB_DEFLATE y
        set_config CONFIG_ZLIB_INFLATE y
        set_config CONFIG_LZO_COMPRESS y
        set_config CONFIG_LZO_DECOMPRESS y
        set_config CONFIG_ZSTD_COMPRESS y
        set_config CONFIG_ZSTD_DECOMPRESS y
        ;;
    xfs) set_config CONFIG_XFS_FS y; unset_config CONFIG_BTRFS_FS ;;
    *) unset_config CONFIG_BTRFS_FS; unset_config CONFIG_XFS_FS ;;
esac

# The trim file lists device tree nodes to delete. Lines for nodes that a feature still needs are left out.
DTS="${SRC}/arch/arm64/boot/dts/qcom/msm8916-yiming-uz801v3.dts"
# With TRIM_DTB=no, the nodes stay in the tree and are disabled with status overrides.
if [ "${TRIM_DTB}" = yes ]; then
    TRIM_FILTER='^$'
    if [ "${MODEM}" = yes ]; then
        TRIM_FILTER="${TRIM_FILTER}|&mba_mem;|&mpss_mem;|rfsa@|rmtfs@|smp2p-hexagon|&hexagon_smsm;|&mpss;"
    fi
    if [ "${BLUETOOTH}" = yes ]; then
        TRIM_FILTER="${TRIM_FILTER}|&wcnss_bt;"
    fi
    if [ "${KERNEL_DEBUG}" = yes ]; then
        TRIM_FILTER="${TRIM_FILTER}|sram@290000"
    fi
    grep -v -E "${TRIM_FILTER}" device/board/uz801v3/uz801v3-kernel-trim.dtsi >> "${DTS}"
fi
{
    if [ "${MODEM}" = yes ]; then
        echo '&mpss { status = "okay"; };'
    elif [ "${TRIM_DTB}" = no ]; then
        echo '&mpss { status = "disabled"; };'
    fi
    if [ "${BLUETOOTH}" = yes ]; then
        echo '&wcnss_bt { status = "okay"; };'
    elif [ "${TRIM_DTB}" = no ]; then
        echo '&wcnss_bt { status = "disabled"; };'
    fi
    if [ "${WIFI}" = no ] && [ "${BLUETOOTH}" = no ]; then
        echo '&wcnss { status = "disabled"; };'
    fi
    if [ "${TRIM_DTB}" = no ]; then
        printf '&%s { status = "disabled"; };\n' gpu mdss venus
    fi
} >> "${DTS}"
if [ "${CRASH_CAPTURE}" = yes ]; then
    CRASH_CAPTURE_NODE=${CRASH_CAPTURE_ADDR#0x}
    export CRASH_CAPTURE_NODE
    render device/image/templates/kernel/ramoops.dtsi.in "${SRC}/ramoops.dtsi.tmp" CRASH_CAPTURE_NODE CRASH_CAPTURE_ADDR CRASH_CAPTURE_SIZE
    cat "${SRC}/ramoops.dtsi.tmp" >> "${DTS}"
    rm -f "${SRC}/ramoops.dtsi.tmp"
fi
# Patches are applied with git in the order of this list. The repository is removed afterwards.
# Each entry is the switch value, a colon, and the patch name in device/kernel/patches/linux.
git -C "${SRC}" init -q
for p in \
    "${PATCH_BBR}:0001-tcp-bbr3-initial-import" \
    "${PATCH_LE9UO}:0001-le9uo" \
    "${PATCH_ZSTD}:0001-zstd-cachyos" \
    "${PATCH_CPR}:0001-cpr" \
    "${PATCH_SMSM}:0001-smsm-skip-empty-mboxes"; do
    if [ "${p%%:*}" = yes ]; then
        git -C "${SRC}" apply "$(pwd)/device/kernel/patches/linux/${p#*:}.patch"
    fi
done
rm -rf "${SRC}/.git"

# The job count comes from MAKEFLAGS, which lib/settings.sh exports.
kmake() { make -C "${SRC}" ARCH=arm64 CROSS_COMPILE="${CROSS_CCACHE}" "$@"; }
# olddefconfig sets defaults for any option that the edits added.
kmake olddefconfig
kmake Image.gz qcom/msm8916-yiming-uz801v3.dtb modules

# The kernel and modules are staged in work/files/kernel. Steps 22 and 64 read them from there.
rm -rf --one-file-system "${OUT}/rootfs"
mkdir -p "${OUT}/rootfs/boot/dtbs/qcom"
cp "${SRC}/arch/arm64/boot/Image.gz" "${OUT}/rootfs/boot/vmlinuz"
cp "${SRC}/arch/arm64/boot/dts/qcom/msm8916-yiming-uz801v3.dtb" "${OUT}/rootfs/boot/dtbs/qcom/${DTB_NAME}"
kmake INSTALL_MOD_PATH="${OUT}/rootfs" INSTALL_MOD_STRIP=1 modules_install
# The release string names the module directory and the kernel package.
KVER=$(make -s -C "${SRC}" ARCH=arm64 kernelrelease)
rm -f "${OUT}/rootfs/lib/modules/${KVER}/build" "${OUT}/rootfs/lib/modules/${KVER}/source"
depmod -b "${OUT}/rootfs" "${KVER}"
echo "${KVER}" > "${OUT}/kernel-release"
