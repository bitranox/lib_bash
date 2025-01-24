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
        text="${CLR_ESC}${codes[*]}m${text}${}
