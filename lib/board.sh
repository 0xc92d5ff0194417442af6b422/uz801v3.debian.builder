
# Board name. It selects the files in device/board/<name>.
BOARD=${BOARD:-uz801v3}
export BOARD

# Partition IDs keep the fixed values from lib/steps/common.sh. An empty value in the config makes a random ID.
# The same values go to the GPT, fstab and extlinux.
ROOT_PARTUUID=${ROOT_PARTUUID:-$(cat /proc/sys/kernel/random/uuid)}
BOOT_PARTUUID=${BOOT_PARTUUID:-$(cat /proc/sys/kernel/random/uuid)}
export ROOT_PARTUUID BOOT_PARTUUID
