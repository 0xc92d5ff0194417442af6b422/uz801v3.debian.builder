#!/bin/sh -e

# Entry point for the OpenStick image build. Run it as root from the repository root.
# It reads the switches, removes generated files when asked, then runs the steps in lib/steps/ in filename order.
set -e

# The chroot is the Debian system that the build assembles. Every step works inside it.
CHROOT=${CHROOT=$(pwd)/work/rootfs}
export CHROOT

FROM=
ONLY=
ONLY_KERNEL=no
ONLY_BOOT_DTB=
CLEAN=no
FRESH=no
CONFIG_FILE=config.env
CONFIG_GIVEN=no
USE_BASE_CACHE=no
USAGE="usage: sh build.sh [--from STEP | --only STEP] [--config FILE] [--only-kernel] [--only-boot FILE] [--use-base-cache] [--clean] [--fresh]"
while [ $# -gt 0 ]; do
    case "$1" in
        --from) FROM=${2:?"--from needs a step name"}; shift 2 ;;
        --from=*) FROM=${1#--from=}; shift ;;
        --only) ONLY=${2:?"--only needs a step name"}; shift 2 ;;
        --only=*) ONLY=${1#--only=}; shift ;;
        --only-kernel) ONLY_KERNEL=yes; shift ;;
        --only-boot) ONLY_BOOT_DTB=${2:?"--only-boot needs a file name"}; shift 2 ;;
        --only-boot=*) ONLY_BOOT_DTB=${1#--only-boot=}; shift ;;
        --clean) CLEAN=yes; shift ;;
        --fresh) CLEAN=yes; FRESH=yes; shift ;;
        --config) CONFIG_FILE=${2:?"--config needs a file name"}; CONFIG_GIVEN=yes; shift 2 ;;
        --config=*) CONFIG_FILE=${1#--config=}; CONFIG_GIVEN=yes; shift ;;
        --use-base-cache) USE_BASE_CACHE=yes; shift ;;
        -h|--help)
            echo "${USAGE}"
            exit 0 ;;
        *) echo "unknown argument: $1" >&2
           echo "${USAGE}" >&2
           exit 2 ;;
    esac
done
export ONLY_KERNEL USE_BASE_CACHE

# Removes generated files. Root is required, because the chroot files belong to root.
# The source checkouts stay, but their contents are removed, so step 15 fetches them again.
if [ "${CLEAN}" = yes ]; then
    if [ -n "${FROM}" ]; then
        echo "--clean and --fresh cannot be used with --from" >&2
        exit 2
    fi
    if [ "$(id -u)" -ne 0 ]; then
        echo "--clean and --fresh remove root-owned build files: run them with sudo" >&2
        exit 2
    fi
    for m in work/rootfs/proc work/rootfs/sys work/rootfs/dev/pts work/rootfs/dev work/rootfs/run work/mnt; do
        umount "${m}" 2>/dev/null || true
    done
    rm -rf --one-file-system work/cache work/files work/rootfs work/rootfs.tgz work/rootfs.raw work/boot.raw work/dist work/build work/mnt
    for d in work/src/*/; do
        [ -d "${d}" ] && rm -rf --one-file-system "${d}"* "${d}".[!.]*
    done
    echo "generated files removed"
    if [ "${FRESH}" != yes ]; then
        echo "--clean: nothing was built"
        exit 0
    fi
fi

# A new build starts with an empty log. A build run with --from or --only appends to it.
LOG=work/files/build.log
mkdir -p work/files
if [ -z "${FROM}${ONLY}" ]; then
    (umask 077; : > "${LOG}")
else
    (umask 077; : >> "${LOG}")
fi

. ./lib/ui.sh
. ./lib/steps/common.sh
# on_exit runs on success and on failure. It unmounts the chroot and closes the log.
trap on_exit EXIT
trap 'exit 1' INT TERM HUP

on_exit() {
    rc=$?
    unmount_all
    if [ "${rc}" -ne 0 ]; then
        msg ERROR "build failed at ${CURRENT_STEP:-startup} (exit code ${rc})"
    fi
    finish_log
    bar_reset
}

# Every script is checked before any step runs, so a syntax error stops the build early.
for s in build.sh lib/*.sh lib/steps/*.sh lib/steps/chroot/*.sh; do
    sh -n "$s" || fail "syntax error in $s"
done

# Output goes through a named pipe. child_output copies each line to the terminal and to the log.
LOG_FIFO=$(mktemp -u)
mkfifo "${LOG_FIFO}"
child_output < "${LOG_FIFO}" &
CHILD_PID=$!
exec > "${LOG_FIFO}" 2>&1
rm -f "${LOG_FIFO}"

# The config file is read with set -a, so each setting is exported to the steps.
if [ "${CONFIG_GIVEN}" = yes ] && [ ! -f "${CONFIG_FILE}" ]; then
    echo "config file not found: ${CONFIG_FILE}" >&2
    exit 2
fi
if [ -f "${CONFIG_FILE}" ]; then
    # Windows line endings (CRLF) are removed first. Otherwise the shell keeps the carriage return in each value.
    set -a
    eval "$(tr -d '\r' < "${CONFIG_FILE}")"
    set +a
fi
# A build run with --from or --only reuses the values that the first run generated. Earlier steps already wrote them into the image.
if [ -n "${FROM}${ONLY}" ] && [ -f work/files/device-info.env ]; then
    for v in HOST_NAME ADMIN_PASSWORD ROOT_PARTUUID BOOT_PARTUUID; do
        saved=$(grep "^${v}=" work/files/device-info.env || true)
        eval "[ -n \"\${${v}}\" ] || ${saved:-:}"
    done
fi

# The helper files define the settings and their checks. They run after the config file is loaded.
. ./lib/settings.sh
. ./lib/checks.sh
. ./lib/board.sh
. ./lib/secrets.sh
. ./lib/boot-image.sh
. ./lib/device-info.sh

# --only-boot rebuilds boot.bin only and skips the steps.
if [ -n "${ONLY_BOOT_DTB}" ]; then
    build_boot_only
    exit 0
fi

# Steps run in filename order. The leading number sets the order.
set -- lib/steps/[0-9]*.sh
# A kernel-only build runs the dependency install, the kernel build and the kernel package.
if [ "${ONLY_KERNEL}" = yes ]; then
    set -- lib/steps/10-install-build-deps.sh lib/steps/21-build-kernel.sh lib/steps/22-package-kernel-deb.sh
fi
if [ -n "${FROM}" ]; then
    selected=$(select_steps "${FROM}" "$@") || fail "no step matches --from ${FROM}"
    set -- ${selected}
    msg INFO "starting at ${FROM}"
fi
if [ -n "${ONLY}" ]; then
    if [ -n "${FROM}" ]; then
        fail "--only and --from cannot be used together"
    fi
    selected=$(select_steps "${ONLY}" "$@") || fail "no step matches --only ${ONLY}"
    set -- "$(printf '%s\n' "${selected}" | head -1)"
    msg INFO "running only ${ONLY}"
fi
# Step 10 installs the host tools. It runs first on every build.
case " $* " in
    *" lib/steps/10-install-build-deps.sh "*) ;;
    *) set -- lib/steps/10-install-build-deps.sh "$@" ;;
esac
# Written before the steps, so a failed build can resume with the same generated values.
# A kernel-only build makes no image, so it keeps the details of the last full build.
if [ "${ONLY_KERNEL}" != yes ]; then
    write_device_info
fi
total=$#
n=0
bar_setup
for s in "$@"; do
    n=$((n + 1))
    CURRENT_STEP=$(basename "${s}" .sh)
    progress "$((n - 1))" "${total}" "${CURRENT_STEP}"
    msg STEP "[${n}/${total}] ${CURRENT_STEP}"
    started=$(date +%s)
    "${s}"
    clear_screen
    msg OK "${CURRENT_STEP} done in $(($(date +%s) - started)) s"
done
progress "${total}" "${total}" finished

msg OK "build finished"
if [ "${ONLY_KERNEL}" != yes ]; then
    msg INFO "${ADMIN_USER} password: ${ADMIN_PASSWORD}"
fi
finish_log
