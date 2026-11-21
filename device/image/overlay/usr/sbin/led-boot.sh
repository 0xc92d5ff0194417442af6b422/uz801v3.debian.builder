#!/bin/sh

# Status LED control for boot. Usage:
#   led-boot.sh progress LED_NAME   light one LED and keep it on
#   led-boot.sh animate             show the ready signal, or blink all LEDs if a service failed
LED_DIR=/sys/class/leds
LEDS="green:wlan blue:wan red:power"

set_led() {
    [ -w "${LED_DIR}/$1/brightness" ] && echo "$2" > "${LED_DIR}/$1/brightness"
}

# all_leds VALUE: set the brightness of every LED
all_leds() {
    for l in ${LEDS}; do set_led "${l}" "$1"; done
}

# no_trigger LED_NAME: stop the kernel trigger, so only this script drives the LED
no_trigger() {
    [ -w "${LED_DIR}/$1/trigger" ] && echo none > "${LED_DIR}/$1/trigger"
}

# progress LED_NAME: a boot stage is reached. The LED blinks twice, then stays on.
progress() {
    no_trigger "$1"
    for _ in 1 2; do
        set_led "$1" 1
        sleep 0.3
        set_led "$1" 0
        sleep 0.3
    done
    set_led "$1" 1
}

animate() {
    # wait until systemd has finished starting: "running", or "degraded" if a unit failed
    state=$(systemctl is-system-running --wait)
    if [ "${state}" != running ]; then
        no_trigger red:power
        # all three LEDs blink together, until the device is restarted with no failed unit
        while :; do
            all_leds 1
            sleep 0.1
            all_leds 0
            sleep 0.1
        done
    fi

    # ready: the stage LEDs stay on, then all three blink together twice and turn off
    for l in ${LEDS}; do no_trigger "${l}"; done
    for _ in 1 2; do
        all_leds 0
        sleep 0.5
        all_leds 1
        sleep 0.5
    done
    all_leds 0
}

case "$1" in
    progress) progress "$2" ;;
    animate) animate ;;
    *) echo "usage: $0 progress LED_NAME | animate" >&2; exit 2 ;;
esac
