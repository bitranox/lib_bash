#!/bin/bash
#
# Constants and functions for terminal colors.
CLR_ESC="\033["

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
CLR_YELLOW=33           # set yellow foreground (changed from BROWN)
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
function fn_exists {
    declare -F "$1" >/dev/null
}

# Process color layers
function clr_layer {
    local CLR_ECHOSWITCHES="-e"
    local CLR_STACK=""
    local CLR_SWITCHES=""
    local ARGS=("$@")

    for ((i=$#-1; i>=0; i--)); do
        local ARG="${ARGS[i]}"
        if [[ "${ARG:0:1}" == "-" ]]; then
            [[ $ARG == "-n" ]] && CLR_ECHOSWITCHES="-en"
            CLR_SWITCHES+=" $ARG"
        else
            if fn_exists "$ARG"; then
                CLR_STACK=$($ARG "$CLR_STACK")
            else
                CLR_STACK="${ARG}${CLR_STACK:+ }${CLR_STACK}"
            fi
        fi
    done

    # Split CLR_STACK into codes and text
    local CODES=()
    local TEXT_PARTS=()
    for part in $CLR_STACK; do
        if [[ $part =~ ^[0-9]+$ ]]; then
            CODES+=("$part")
        else
            TEXT_PARTS+=("$part")
        fi
    done
    local TEXT="${TEXT_PARTS[*]}"

    clr_escape "$TEXT" "${CODES[@]}"
}

# Escape sequence generator
function clr_escape {
    local text="$1"
    shift
    local codes=("$@")

    # Validate and collect codes
    for code in "${codes[@]}"; do
        if [[ ! "$code" =~ ^[0-9]+$ || "$code" -lt 0 || "$code" -gt 49 ]]; then
            echo "Invalid escape code: $code" >&2
            return 1
        fi
    done

    # Build escape sequence
    if [ ${#codes[@]} -gt 0 ]; then
        local IFS=';'
        text="${CLR_ESC}${codes[*]}m${text}${CLR_ESC}${CLR_RESET}m"
    fi

    echo $CLR_ECHOSWITCHES "$text"
}

# Color functions
function clr_reset           { clr_layer $CLR_RESET "$@";           }
function clr_reset_underline { clr_layer $CLR_RESET_UNDERLINE "$@"; }
function clr_reset_reverse   { clr_layer $CLR_RESET_REVERSE "$@";   }
function clr_default         { clr_layer $CLR_DEFAULT "$@";         }
function clr_defaultb        { clr_layer $CLR_DEFAULTB "$@";        }
function clr_bold            { clr_layer $CLR_BOLD "$@";            }
function clr_underscore      { clr_layer $CLR_UNDERSCORE "$@";      }
function clr_reverse         { clr_layer $CLR_REVERSE "$@";         }
function clr_black           { clr_layer $CLR_BLACK "$@";           }
function clr_red             { clr_layer $CLR_RED "$@";             }
function clr_green           { clr_layer $CLR_GREEN "$@";           }
function clr_yellow          { clr_layer $CLR_YELLOW "$@";          }
function clr_blue            { clr_layer $CLR_BLUE "$@";            }
function clr_magenta         { clr_layer $CLR_MAGENTA "$@";         }
function clr_cyan            { clr_layer $CLR_CYAN "$@";            }
function clr_white           { clr_layer $CLR_WHITE "$@";           }
function clr_blackb          { clr_layer $CLR_BLACKB "$@";          }
function clr_redb            { clr_layer $CLR_REDB "$@";            }
function clr_greenb          { clr_layer $CLR_GREENB "$@";          }
function clr_yellowb         { clr_layer $CLR_YELLOWB "$@";         }
function clr_blueb           { clr_layer $CLR_BLUEB "$@";           }
function clr_magentab        { clr_layer $CLR_MAGENTAB "$@";        }
function clr_cyanb           { clr_layer $CLR_CYANB "$@";           }
function clr_whiteb          { clr_layer $CLR_WHITEB "$@";          }

function clr_dump {
    # Define foreground and background color codes and names
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

    # Iterate over each foreground and background combination
    for fg_entry in "${fg_colors[@]}"; do
        local fg_code="${fg_entry%%:*}"
        local fg_name="${fg_entry##*:}"
        for bg_entry in "${bg_colors[@]}"; do
            local bg_code="${bg_entry%%:*}"
            local bg_name="${bg_entry##*:}"
            # Skip combinations where background is the same as foreground
            if (( bg_code - fg_code == 10 )); then
                continue
            fi
            # Construct the escape sequences
            local start="${CLR_ESC}${fg_code};${bg_code}m"
            local reset="${CLR_ESC}${CLR_RESET}m"
            # Print the formatted text and description
            printf "%b%s%b - %s on %s\n" "$start" "Text" "$reset" "$fg_name" "$bg_name"
        done
    done
}

# Utility functions
function fail {
    clr_red "$(clr_bold "[ERROR] ${1}")" >&2
    exit 1
}

function warn {
    clr_yellow "$(clr_bold "[WARNING] ${1}")" >&2
}

# Only execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "$1" in
        -d|--dump)
            clr_dump
            ;;
        *)
            echo "Usage: ${0##*/} [--dump]"
            exit 1
            ;;
    esac
fi