#!/bin/sh -e

# ZRAM_PERCENT is set at build time in /etc/default/zram-swap
ZRAM_PERCENT=50
[ -f /etc/default/zram-swap ] && . /etc/default/zram-swap

case "$1" in
start)
    modprobe zram
    echo zstd > /sys/block/zram0/comp_algorithm
    awk -v p="${ZRAM_PERCENT}" '/MemTotal/ { printf "%d\n", $2 * 1024 * p / 100 }' /proc/meminfo > /sys/block/zram0/disksize
    mkswap /dev/zram0
    swapon -p 100 /dev/zram0
    ;;
stop)
    swapoff /dev/zram0
    echo 1 > /sys/block/zram0/reset
    ;;
esac
