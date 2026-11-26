# Reads a config file into the shell without running it. Values are plain text: $, backquotes and backslashes are kept as they are.
# Accepted lines: blank lines, # comments, NAME=value (no spaces or quotes), and NAME="value" with an optional # comment after it.
# A double-quoted value can span several lines. Call it with set -a, so each value is exported.
read_config() {
    cfg_file=$1
    cfg_cr=$(printf '\r')
    cfg_no=0
    cfg_name=
    cfg_value=
    cfg_open=no
    while IFS= read -r cfg_line || [ -n "${cfg_line}" ]; do
        cfg_no=$((cfg_no + 1))
        cfg_line=${cfg_line%"${cfg_cr}"}
        if [ "${cfg_open}" = yes ]; then
            case "${cfg_line}" in
                *'"'*)
                    cfg_value="${cfg_value}
${cfg_line%%\"*}"
                    cfg_rest=${cfg_line#*\"}
                    cfg_open=no
                    ;;
                *)
                    cfg_value="${cfg_value}
${cfg_line}"
                    continue
                    ;;
            esac
        else
            cfg_ws=${cfg_line%%[! ]*}
            cfg_trim=${cfg_line#"${cfg_ws}"}
            case "${cfg_trim}" in
                ''|'#'*) continue ;;
                *=*) ;;
                *) fail "${cfg_file} line ${cfg_no}: expected NAME=\"value\"" ;;
            esac
            cfg_name=${cfg_trim%%=*}
            cfg_rest=${cfg_trim#*=}
            case "${cfg_name}" in
                ''|[!A-Z_]*|*[!A-Z0-9_]*) fail "${cfg_file} line ${cfg_no}: bad name: ${cfg_name}" ;;
            esac
            case "${cfg_rest}" in
                '"'*)
                    cfg_rest=${cfg_rest#\"}
                    case "${cfg_rest}" in
                        *'"'*)
                            cfg_value=${cfg_rest%%\"*}
                            cfg_rest=${cfg_rest#*\"}
                            ;;
                        *)
                            cfg_value=${cfg_rest}
                            cfg_open=yes
                            continue
                            ;;
                    esac
                    ;;
                *)
                    case "${cfg_rest}" in
                        *[!A-Za-z0-9_.,:/@%+=-]*) fail "${cfg_file} line ${cfg_no}: put the value of ${cfg_name} in double quotes" ;;
                    esac
                    cfg_value=${cfg_rest}
                    cfg_rest=
                    ;;
            esac
        fi
        # Only spaces or a # comment may follow the closing quote.
        cfg_tail=${cfg_rest#"${cfg_rest%%[! ]*}"}
        case "${cfg_tail}" in
            ''|'#'*) ;;
            *) fail "${cfg_file} line ${cfg_no}: text after the closing quote of ${cfg_name}" ;;
        esac
        # The name is checked above, so eval only sets that one variable. The value is never parsed as code.
        eval "${cfg_name}=\${cfg_value}"
        cfg_value=
    done < "${cfg_file}"
    if [ "${cfg_open}" = yes ]; then
        fail "${cfg_file}: missing closing quote for ${cfg_name}"
    fi
}
