#!/bin/bash
# lib_color.sh
set -o errexit -o nounset -o pipefail

# Constants and functions for terminal colors.
CLR_ESC='\033['

# Ensure we're running in bash
if [[ -z "${BASH_VERSION:-}" ]]; then
    echo "This script requires bash" >&2
    exit 1
fi

# All these variables have a function with the same name, but in lower case.
CLR_RESET=0             # reset all attributes to their defaults
CLR_RESET_UNDERLINE=24  # underline off
CLR_RESET_REVERSE=27    # reverse off
CLR_DEFAULT=39          # set default foreground color
CLR_DEFAULTB=49         # set default background color

CLR_BOLD=1              # set bold
CLR_UNDERSCORE=4        # set underscore
CLR_REVERSE=7           # set reverse video

CLR_BLACK=30            # set black foreground
CLR_RED=31              # set red foreground
CLR_GREEN=32            # set green foreground
CLR_YELLOW=33           # set yellow foreground
CLR_BLUE=34             # set blue foreground
CLR_MAGENTA=35          # set magenta foreground
CLR_CYAN=36             # set cyan foreground
CLR_WHITE=37            # set white foreground

CLR_BLACKB=40           # set black background
CLR_REDB=41             # set red background
CLR_GREENB=42           # set green background
CLR_YELLOWB=43          # set yellow background
CLR_BLUEB=44            # set blue background
CLR_MAGENTAB=45         # set magenta background
CLR_CYANB=46            # set cyan background
CLR_WHITEB=47           # set white background

# Check if string exists as function
fn_exists() {
    declare -F "$1" >/dev/null
}

clr_layer() {
    local CLR_ECHOSWITCHES="-e"
    local CLR_STACK=""
    local CLR_SWITCHES=""
    local ARGS=("$@")

    if [[ $# -eq 0 ]]; then
        return 0
    fi

    # 1) Create a reversed copy of ARGS (so we can iterate forward but
    #    preserve the old right-to-left processing logic).
    local REVERSED=()
    for (( i=${#ARGS[@]}-1; i>=0; i-- )); do
        REVERSED+=( "${ARGS[i]}" )
    done

    # 2) Process REVERSED in forward order, which replicates the old
    #    "reverse iteration" effect on the final output.
    for ARG in "${REVERSED[@]}"; do
        if [[ "${ARG:0:1}" == "-" ]]; then
            # e.g. -n => echo -en
            [[ $ARG == "-n" ]] && CLR_ECHOSWITCHES="-en"
            CLR_SWITCHES+=" $ARG"
        else
            # If ARG is one of our color/attribute functions, invoke it on the current stack
            if fn_exists "$ARG"; then
                CLR_STACK=$($ARG "$CLR_STACK")
            else
                # Otherwise treat it as literal text (or a numeric code).
                # Prepend to keep the old layering logic.
                CLR_STACK="${ARG}${CLR_STACK:+ }${CLR_STACK}"
            fi
        fi
    done

    # Separate out numeric codes vs text
    local CODES=()
    local TEXT_PARTS=()
    local part
    for part in $CLR_STACK; do
        if [[ $part =~ ^[0-9]+$ ]]; then
            CODES+=("$part")
        else
            TEXT_PARTS+=("$part")
        fi
    done

    local TEXT="${TEXT_PARTS[*]}"
    clr_escape "$CLR_ECHOSWITCHES" "$TEXT" "${CODES[@]}"
}


# Escape sequence generator
clr_escape() {
    # 1st arg = echo switches (-e, -en, etc.)
    local echoswitches="$1"
    shift
    local text="$1"
    shift
    local codes=("$@")

    # Validate codes
    for code in "${codes[@]}"; do
        if [[ ! "$code" =~ ^[0-9]+$ || "$code" -lt 0 || "$code" -gt 49 ]]; then
            echo "Invalid escape code: $code" >&2
            return 1
        fi
    done

    # Build escape sequence if codes exist
    if [ ${#codes[@]} -gt 0 ]; then
        local IFS=';'
        text="${CLR_ESC}${codes[*]}m${text}${CLR_ESC}${CLR_RESET}m"
    fi

    # Print with the correct echo flags
    echo $echoswitches "$text"
}

# Color functions
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

# Dump all color combinations
clr_dump() {
    local fg_colors=(
        "30:BLACK"
        "31:RED"
        "32:GREEN"
        "33:YELLOW"
        "34:BLUE"
        "35:MAGENTA"
        "36:CYAN"
        "37:WHITE"
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
    )

    for fg_entry in "${fg_colors[@]}"; do
        local fg_code="${fg_entry%%:*}"
        local fg_name="${fg_entry##*:}"
        for bg_entry in "${bg_colors[@]}"; do
            local bg_code="${bg_entry%%:*}"
            local bg_name="${bg_entry##*:}"

            (( bg_code - fg_code == 10 )) && continue

            local reset="${CLR_ESC}${CLR_RESET}m"
            local base="${CLR_ESC}${fg_code};${bg_code}m"
            local bold="${CLR_ESC}${CLR_BOLD};${fg_code};${bg_code}m"
            local under="${CLR_ESC}${CLR_UNDERSCORE};${fg_code};${bg_code}m"
            local reverse="${CLR_ESC}${CLR_REVERSE};${fg_code};${bg_code}m"

            printf "%bText (Normal)%b  " "$base" "$reset"
            printf "%bText (Bold)%b  " "$bold" "$reset"
            printf "%bText (Underscore)%b  " "$under" "$reset"
            printf "%bText (Reverse)%b  " "$reverse" "$reset"
            printf " - %s on %s\n" "$fg_name" "$bg_name"
        done
    done
}

# Main execution handler
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

