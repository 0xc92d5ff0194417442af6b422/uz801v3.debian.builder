
# Makes a 24 character password. It has all four character classes and no run of four equal characters.
gen_admin_password() {
    while :; do
        p=$(LC_ALL=C tr -dc 'A-Za-z0-9!#%+,./:=?@^_-' < /dev/urandom | head -c 24)
        case "$p" in *[A-Z]*) ;; *) continue ;; esac
        case "$p" in *[a-z]*) ;; *) continue ;; esac
        case "$p" in *[0-9]*) ;; *) continue ;; esac
        case "$p" in *[!A-Za-z0-9]*) ;; *) continue ;; esac
        printf '%s\n' "$p" | grep -qE '(.)\1\1\1' && continue
        break
    done
    printf '%s' "$p"
}
# Created once per build and printed at the end. Set the variable to use a fixed password.
ADMIN_PASSWORD=${ADMIN_PASSWORD:-$(gen_admin_password)}
export ADMIN_PASSWORD
