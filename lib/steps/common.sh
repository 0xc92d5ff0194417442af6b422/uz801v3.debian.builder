BOARD_COMPATIBLE=${BOARD_COMPATIBLE:-"yiming,uz801-v3"}
LK2ND_BUNDLE_DTB=${LK2ND_BUNDLE_DTB:-"msm8916-512mb-mtp.dtb"}
DTB_NAME=${DTB_NAME:-"msm8916-yiming-uz801v3.dtb"}
ROOT_PARTUUID=${ROOT_PARTUUID-"a8700358-1761-459b-9774-5f21e5185a66"}
BOOT_PARTUUID=${BOOT_PARTUUID-"6906df5e-69e3-4b1b-815e-3ec68e41b941"}
BOOT_ARGS=${BOOT_ARGS-"no_framebuffer=true cma=4M rw rootwait"}
FW_URL=${FW_URL-"https://archive.org/download/dragonboard-410c-bootloader-emmc-linux-176/dragonboard-410c-bootloader-emmc-linux-176.zip"}
FW_SHA256=${FW_SHA256-"a37c4e82a970ae2350fcfc7180559caf1dc3928e7c169316fe4ab899b7d305ad"}
KERNEL_TAG=${KERNEL_TAG:-"linux-6.12.118"}
KERNEL_SRC_URL=${KERNEL_SRC_URL:-"https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.118.tar.xz"}
KERNEL_SRC_SHA512=${KERNEL_SRC_SHA512:-"2f3a7a45db7af4a2af2d08e56e6e587c5b7e08427bf11b78bdde005ad91886debad2e24edd75e28652e0e6589f8b8408edb41281372db04cc11428a5442c71e1"}
KERNEL_CONFIG_COMMIT=${KERNEL_CONFIG_COMMIT:-"5832e3453ab7ec4483b1f6c6479b5bd45985e4d7"}
KERNEL_CONFIG_SHA512=${KERNEL_CONFIG_SHA512:-"67b6141ad2d3634177194a1ae58f08566a9dd33936c9a5d429bad785320c7b9bf1c676ba1cedf438d235413195fb15236867ccfc3310cf5a77a4bce4781fb8e4"}
export BOARD_COMPATIBLE LK2ND_BUNDLE_DTB DTB_NAME ROOT_PARTUUID BOOT_PARTUUID BOOT_ARGS FW_URL FW_SHA256 KERNEL_TAG KERNEL_SRC_URL KERNEL_SRC_SHA512 KERNEL_CONFIG_COMMIT KERNEL_CONFIG_SHA512

# Unmounts the chroot filesystems and work/mnt. A lazy unmount is the fallback when a process still uses one.
unmount_all() {
    for m in "${CHROOT}/dev/pts" "${CHROOT}/dev" "${CHROOT}/proc" "${CHROOT}/sys" "${CHROOT}/run" work/mnt; do
        if mountpoint -q "$m"; then
            umount "$m" || umount -l "$m" || echo "WARNING: could not unmount $m" >&2
        fi
    done
}

# dtc warnings are turned off, because the vendor device tree triggers many of them.
compile_dtb() {
    dtc -W no-unique_unit_address -W no-clocks_property -W no-avoid_unnecessary_addr_size \
        -W no-dmas_property -W no-power_domains_property -W no-cooling_device_property \
        -I dts -O dtb -o "$2" "$1"
}

# Fills @NAME@ placeholders in a template. Values are escaped for sed.
# The step stops when the template has a placeholder that the call does not name.
# The check reads the template, not the output, so a value such as a password can contain @TEXT@.
render() {
    src=$1
    dest=$2
    shift 2
    for name in $(grep -oE '@[A-Z_][A-Z0-9_]*@' "${src}" | tr -d @ | sort -u); do
        case " $* " in
            *" ${name} "*) ;;
            *) echo "render: @${name}@ has no value in ${src}" >&2; exit 1 ;;
        esac
    done
    script=""
    for name in "$@"; do
        escaped=$(eval "printf '%s' \"\${${name}}\"" | sed -e 's/[\\/&|]/\\&/g')
        script="${script}s|@${name}@|${escaped}|g;"
    done
    sed -e "${script}" "${src}" > "${dest}"
}

# Prints the named step and every step after it. The name can be the step number alone.
# It fails when no step matches.
select_steps() {
    from=$1
    shift
    skip=1
    for s in "$@"; do
        case "$(basename "${s}" .sh)" in "${from}"|"${from}"-*) skip=0 ;; esac
        if [ "${skip}" -eq 0 ]; then
            printf '%s\n' "${s}"
        fi
    done
    [ "${skip}" -eq 0 ]
}

# Builds work/files/boot.bin from a folder. Step 90 and --only-boot share it, so both images match fstab.
make_boot_image() {
    [ -d "$1" ] || { echo "make_boot_image: folder not found: $1" >&2; return 1; }
    rm -f work/boot.raw
    truncate -s "${BOOT_SIZE}" work/boot.raw
    mkfs.ext2 -q -d "$1" work/boot.raw
    img2simg work/boot.raw work/files/boot.bin
}
