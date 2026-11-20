
# Colours are used only on a terminal, so log files stay plain text.
if [ -t 1 ]; then
    C_STEP=$(printf '\033[1;36m')
    C_OK=$(printf '\033[32m')
    C_WARN=$(printf '\033[33m')
    C_ERR=$(printf '\033[31m')
    C_OFF=$(printf '\033[0m')
else
    C_STEP='' C_OK='' C_WARN='' C_ERR='' C_OFF=''
fi

# Keeps the terminal on file descriptors 3 and 4. build.sh later sends stdout and stderr to the log pipe.
exec 3>&1 4>&2

# Shows a message on the terminal and writes the same line to the log.
msg() {
    level=$1
    shift
    case "${level}" in
        STEP) colour=${C_STEP} ;;
        OK) colour=${C_OK} ;;
        WARN) colour=${C_WARN} ;;
        ERROR) colour=${C_ERR} ;;
        *) colour='' ;;
    esac
    printf '%s[%s]%s %s\n' "${colour}" "${level}" "${C_OFF}" "$*" >&3
    printf '%s [%-5s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${level}" "$*" >> "${LOG}"
}

fail() {
    msg ERROR "$*"
    exit 1
}

clear_screen() {
    [ -t 3 ] && printf '\033[2J\033[H' >&3
    return 0
}

ESC=$(printf '\033')
BAR_ROWS=

# Sets a scroll region that leaves the last terminal line free for the progress bar.
bar_setup() {
    [ -t 3 ] || return 0
    BAR_ROWS=$(stty size <&3 | cut -d' ' -f1)
    printf '%s[1;%sr%s[%s;1H' "${ESC}" "$((BAR_ROWS - 1))" "${ESC}" "$((BAR_ROWS - 1))" >&3
}

bar_reset() {
    [ -n "${BAR_ROWS}" ] || return 0
    printf '%s[r%s[%s;1H\n' "${ESC}" "${ESC}" "${BAR_ROWS}" >&3
    BAR_ROWS=
}

# Draws the progress bar in the reserved line. Without a reserved line, it prints a plain text line.
progress() {
    width=30
    filled=$(($1 * width / $2))
    bar=$(printf '%*s' "${filled}" '' | tr ' ' '#')
    rest=$(printf '%*s' "$((width - filled))" '' | tr ' ' '-')
    text="${C_STEP}[${bar}${rest}] $1/$2 ($3)${C_OFF}"
    if [ -n "${BAR_ROWS}" ]; then
        printf '%s7%s[%s;1H%s[2K%s%s8' "${ESC}" "${ESC}" "${BAR_ROWS}" "${ESC}" "${text}" "${ESC}" >&3
    else
        printf '%s\n' "${text}" >&3
    fi
}

# Reads the build output from the pipe. Each line goes to the terminal and to the log.
child_output() {
    exec 5>>"${LOG}"
    while IFS= read -r line; do
        printf '%s\n' "${line}"
        printf '    | %s\n' "${line}" >&5
    done
}

CHILD_PID=
# Closes the pipe, then waits for child_output to write its last lines.
finish_log() {
    [ -n "${CHILD_PID}" ] || return 0
    exec >&- 2>&-
    wait "${CHILD_PID}"
    CHILD_PID=
}
