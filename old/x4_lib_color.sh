#!/bin/bash
# lib_color.sh
set -o errexit -o nounset -o pipefail

#####################################################################
# 1) Standard 16-color constants & checks
#####################################################################

CLR_ESC='\033['

if [[ -z "${BASH_VERSION:-}" ]]; then
    echo "This script requires bash" >&2
    exit 1
fi

# Basic SGR reset and attribute codes
CLR_RESET=0             # reset all attributes to default
CLR_RESET_UNDERLINE=24  # underline off
CLR_RESET_REVERSE=27    # reverse off
CLR_DEFAULT=39          # default foreground
CLR_DEFAULTB=49         # default background
CLR_BOLD=1
CLR_UNDERSCORE=4
CLR_REVERSE=7

# 8 basic foreground colors (30..37)
CLR_BLACK=30
CLR_RED=31
CLR_GREEN=32
CLR_YELLOW=33
CLR_BLUE=34
CLR_MAGENTA=35
CLR_CYAN=36
CLR_WHITE=37

# 8 basic background colors (40..47)
CLR_BLACKB=40
CLR_REDB=41
CLR_GREENB=42
CLR_YELLOWB=43
CLR_BLUEB=44
CLR_MAGENTAB=45
CLR_CYANB=46
CLR_WHITEB=47

#####################################################################
# 2) Function check
#####################################################################
fn_exists() {
    declare -F "$1" &>/dev/null
}

#####################################################################
# 3) clr_layer() - updated to avoid the direct reverse for-loop
#    but preserve the same "last arg processed first" layering
#####################################################################
clr_layer() {
    local CLR_ECHOSWITCHES="-e"
    local CLR_STACK=""
    local CLR_SWITCHES=""
    local ARGS=("$@")

    if [[ $# -eq 0 ]]; then
        return 0
    fi

    # Reverse the args, same as before
    local REVERSED=()
    for (( i=${#ARGS[@]}-1; i>=0; i-- )); do
        REVERSED+=( "${ARGS[i]}" )
    done

    # Use a special delimiter (e.g. ASCII 30 or literal <SEP>) to store each token
    local DELIM=$'\x1E'  # Record Separator, or just use "<SEP>"

    for ARG in "${REVERSED[@]}"; do
        if [[ "${ARG:0:1}" == "-" ]]; then
            [[ "$ARG" == "-n" ]] && CLR_ECHOSWITCHES="-en"
            CLR_SWITCHES+=" $ARG"
        else
            if fn_exists "$ARG"; then
                # A known color/attribute function, call it with the current stack as a single string
                # Rejoin CLR_STACK by the chosen delimiter so the function sees everything as one string
                local CURRENT_TEXT
                # Turn the delimiter-based string back into spaced text:
                # (shellsafe but straightforward)
                IFS="$DELIM" read -r -a parts <<< "$CLR_STACK"
                CURRENT_TEXT="${parts[*]}" # join with space

                CURRENT_TEXT="$($ARG "$CURRENT_TEXT")"

                # Now store it back into CLR_STACK as a single token
                CLR_STACK="$CURRENT_TEXT"
            else
                # Prepend ARG to CLR_STACK, separated by DELIM, so we don't split on spaces
                if [[ -z "$CLR_STACK" ]]; then
                    CLR_STACK="$ARG"
                else
                    CLR_STACK="$ARG$DELIM$CLR_STACK"
                fi
            fi
        fi
    done

    # Now parse $CLR_STACK by $DELIM, *not* by spaces
    local items=()
    local DELIM_FINAL=$'\x1E'
    IFS="$DELIM_FINAL" read -r -a items <<< "$CLR_STACK"

    # We'll put numeric/extended codes into CODES; everything else is text
    local CODES=()
    local TEXT_PARTS=()

    for part in "${items[@]}"; do
        # If it has a semicolon, assume extended code like "38;5;196"
        # If it is purely numeric, 0..107
        # else treat as text
        if [[ "$part" == *";"* ]]; then
            CODES+=("$part")
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            # plain numeric code
            CODES+=("$part")
        else
            # text
            TEXT_PARTS+=("$part")
        fi
    done

    local TEXT="${TEXT_PARTS[*]}"
    clr_escape "$CLR_ECHOSWITCHES" "$TEXT" "${CODES[@]}"
}

#####################################################################
# 4) clr_escape() - now allows extended codes like "38;5;NNN"
#####################################################################
clr_escape() {
    local echoswitches="$1"
    shift
    local text="$1"
    shift
    local codes=("$@")

    for code in "${codes[@]}"; do
        # If code has a semicolon, skip numeric check
        if [[ "$code" == *";"* ]]; then
            :
        else
            # Must be a normal 0..107 code or we throw "Invalid escape code"
            if [[ ! "$code" =~ ^[0-9]+$ || "$code" -lt 0 || "$code" -gt 107 ]]; then
                echo "Invalid escape code: $code" >&2
                return 1
            fi
        fi
    done

    if [ ${#codes[@]} -gt 0 ]; then
        local IFS=';'
        text="${CLR_ESC}${codes[*]}m${text}${CLR_ESC}${CLR_RESET}m"
    fi

    echo $echoswitches "$text"
}


#####################################################################
# 5) Basic color wrapper functions
#####################################################################
clr_reset()           { clr_layer $CLR_RESET "$@";           }
clr_reset_underline() { clr_layer $CLR_RESET_UNDERLINE "$@"; }
clr_reset_reverse()   { clr_layer $CLR_RESET_REVERSE "$@";   }
clr_default()         { clr_layer $CLR_DEFAULT "$@";         }
clr_defaultb()        { clr_layer $CLR_DEFAULTB "$@";        }
clr_bold()            { clr_layer $CLR_BOLD "$@";            }
clr_underscore()      { clr_layer $CLR_UNDERSCORE "$@";      }
clr_reverse()         { clr_layer $CLR_REVERSE "$@";         }
clr_black()           { clr_layer $CLR_BLACK "$@";           }
clr_red()             { clr_layer $CLR_RED "$@";             }
clr_green()           { clr_layer $CLR_GREEN "$@";           }
clr_yellow()          { clr_layer $CLR_YELLOW "$@";          }
clr_blue()            { clr_layer $CLR_BLUE "$@";            }
clr_magenta()         { clr_layer $CLR_MAGENTA "$@";         }
clr_cyan()            { clr_layer $CLR_CYAN "$@";            }
clr_white()           { clr_layer $CLR_WHITE "$@";           }
clr_blackb()          { clr_layer $CLR_BLACKB "$@";          }
clr_redb()            { clr_layer $CLR_REDB "$@";            }
clr_greenb()          { clr_layer $CLR_GREENB "$@";          }
clr_yellowb()         { clr_layer $CLR_YELLOWB "$@";         }
clr_blueb()           { clr_layer $CLR_BLUEB "$@";           }
clr_magentab()        { clr_layer $CLR_MAGENTAB "$@";        }
clr_cyanb()           { clr_layer $CLR_CYANB "$@";           }
clr_whiteb()          { clr_layer $CLR_WHITEB "$@";          }

#####################################################################
# 6) 256-color support
#####################################################################
# Usage: clr_256fg [0..255] "text..."
#        clr_256bg [0..255] "text..."
# Will produce \033[38;5;NNNm or \033[48;5;NNNm
#####################################################################
clr_256fg() {
    local code="$1"
    shift
    if [[ ! "$code" =~ ^[0-9]{1,3}$ ]] || (( code < 0 || code > 255 )); then
        echo "Invalid 256 FG code: $code" >&2
        return 1
    fi
    # This calls clr_layer with the extended code "38;5;${code}"
    clr_layer "38;5;${code}" "$@"
}

clr_256bg() {
    local code="$1"
    shift
    if [[ ! "$code" =~ ^[0-9]{1,3}$ ]] || (( code < 0 || code > 255 )); then
        echo "Invalid 256 BG code: $code" >&2
        return 1
    fi
    clr_layer "48;5;${code}" "$@"
}

#####################################################################
# 7) clr_dump() - expanded to show both standard combos + 256 palette
#####################################################################
clr_dump() {
    echo "==== 16-Color / 8-Color Combinations ===="
    local fg_colors=(
        "30:BLACK"
        "31:RED"
        "32:GREEN"
        "33:YELLOW"
        "34:BLUE"
        "35:MAGENTA"
        "36:CYAN"
        "37:WHITE"
        "90:BRIGHT_BLACK"
        "91:BRIGHT_RED"
        "92:BRIGHT_GREEN"
        "93:BRIGHT_YELLOW"
        "94:BRIGHT_BLUE"
        "95:BRIGHT_MAGENTA"
        "96:BRIGHT_CYAN"
        "97:BRIGHT_WHITE"
    )
    local bg_colors=(
        "40:BLACKB"
        "41:REDB"
        "42:GREENB"
        "43:YELLOWB"
        "44:BLUEB"
        "45:MAGENTAB"
        "46:CYANB"
        "47:WHITEB"
        "100:BRIGHT_BLACKB"
        "101:BRIGHT_REDB"
        "102:BRIGHT_GREENB"
        "103:BRIGHT_YELLOWB"
        "104:BRIGHT_BLUEB"
        "105:BRIGHT_MAGENTAB"
        "106:BRIGHT_CYANB"
        "107:BRIGHT_WHITEB"
    )

    for fg_entry in "${fg_colors[@]}"; do
        local fg_code="${fg_entry%%:*}"
        local fg_name="${fg_entry##*:}"
        for bg_entry in "${bg_colors[@]}"; do
            local bg_code="${bg_entry%%:*}"
            local bg_name="${bg_entry##*:}"

            # skip identical combos if you want
            local reset="${CLR_ESC}${CLR_RESET}m"
            local base="${CLR_ESC}${fg_code};${bg_code}m"
            local bold="${CLR_ESC}${CLR_BOLD};${fg_code};${bg_code}m"
            local under="${CLR_ESC}${CLR_UNDERSCORE};${fg_code};${bg_code}m"
            local reverse="${CLR_ESC}${CLR_REVERSE};${fg_code};${bg_code}m"

            printf "%bText (Normal)%b  "  "$base"    "$reset"
            printf "%bText (Bold)%b  "    "$bold"    "$reset"
            printf "%bText (Under)%b  "   "$under"   "$reset"
            printf "%bText (Revs)%b  "    "$reverse" "$reset"
            printf " - %s on %s\n" "$fg_name" "$bg_name"
        done
    done

    echo
    echo "==== 256-Color Foreground Table ===="
    # 6x6 color cube from 16..231, plus grayscale from 232..255
    # We'll do a quick 16-wide output
    for c in {0..255}; do
        printf "\033[38;5;%sm%3d " "$c" "$c"
        if (( c % 16 == 15 )); then
            printf "\033[0m\n"
        fi
    done
    printf "\033[0m\n"

    echo
    echo "==== 256-Color Background Table ===="
    for c in {0..255}; do
        printf "\033[48;5;%sm%3d " "$c" "$c"
        if (( c % 16 == 15 )); then
            printf "\033[0m\n"
        fi
    done
    printf "\033[0m\n"

    echo "End of clr_dump."
}

#####################################################################
# 8) Main entry point (if called directly)
#####################################################################
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$#" -eq 0 ]]; then
        echo "Usage: ${0##*/} [--dump] or function_name [arguments]" >&2
        exit 1
    fi

    case "$1" in
        -d|--dump)
            clr_dump
            ;;
        *)
            if fn_exists "$1"; then
                func="$1"
                shift
                $func "$@"
            else
                echo "Invalid command: $1" >&2
                exit 1
            fi
            ;;
    esac
fi
