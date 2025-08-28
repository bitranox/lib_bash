#!/bin/bash
# lib_color.sh — Terminal color and style helpers for Bash
#
# Purpose:
# - Simple functions to decorate strings with ANSI SGR codes.
# - Supports standard, bright, and 256-color foreground/background.
# - Includes style helpers (bold, underscore, reverse, italic, blink).
#
# Usage:
# - Source and call: `clr_red "Error"`, `clr_256fg 196 "Hi"`, or pipeline via `clr_layer`.
# - Run as a script with `--dump` to print color tables.
#
# Notes:
# - Strict mode and an error trap when executed directly; safe to source.
# - Requires Bash (uses arrays and `${BASH_SOURCE[@]}`).

# For detection if the script is sourced correctly
# shellcheck disable=SC2034
LIB_COLOR_LOADED=true

_lib_color_is_in_script_mode() {
  case "${BASH_SOURCE[0]}" in
    "${0}") return 0 ;;  # script mode
    *)      return 1 ;;
  esac
}

# --- only in script mode ---
if _lib_color_is_in_script_mode; then
  # Strict mode & traps only when run directly
  set -Eeuo pipefail
  IFS=$'\n\t'
  umask 022
  # shellcheck disable=SC2154
  trap 'ec=$?; echo "ERR $ec at ${BASH_SOURCE[0]}:${LINENO}: ${BASH_COMMAND}" >&2' ERR
fi


#####################################################################
# 1) Basic SGR (Select Graphic Rendition) codes
#####################################################################
CLR_ESC='\033['

# Ensure we're in Bash
if [[ -z "${BASH_VERSION:-}" ]]; then
    echo "This script requires bash" >&2
    exit 1
fi

# Reset + attribute codes
CLR_RESET=0
CLR_RESET_UNDERLINE=24
CLR_RESET_REVERSE=27
CLR_DEFAULT=39
CLR_DEFAULTB=49

CLR_BOLD=1
CLR_UNDERSCORE=4
CLR_REVERSE=7

# Newly added
CLR_ITALIC=3
CLR_BLINK=5

# 8 standard FG (30..37)
CLR_BLACK=30
CLR_RED=31
CLR_GREEN=32
CLR_YELLOW=33
CLR_BLUE=34
CLR_MAGENTA=35
CLR_CYAN=36
CLR_WHITE=37

# 8 standard BG (40..47)
CLR_BLACKB=40
CLR_REDB=41
CLR_GREENB=42
CLR_YELLOWB=43
CLR_BLUEB=44
CLR_MAGENTAB=45
CLR_CYANB=46
CLR_WHITEB=47

# **Bright** FG (90..97)
CLR_BRIGHT_BLACK=90
CLR_BRIGHT_RED=91
CLR_BRIGHT_GREEN=92
CLR_BRIGHT_YELLOW=93
CLR_BRIGHT_BLUE=94
CLR_BRIGHT_MAGENTA=95
CLR_BRIGHT_CYAN=96
CLR_BRIGHT_WHITE=97

# **Bright** BG (100..107)
CLR_BRIGHT_BLACKB=100
CLR_BRIGHT_REDB=101
CLR_BRIGHT_GREENB=102
CLR_BRIGHT_YELLOWB=103
CLR_BRIGHT_BLUEB=104
CLR_BRIGHT_MAGENTAB=105
CLR_BRIGHT_CYANB=106
CLR_BRIGHT_WHITEB=107

#####################################################################
# 2) fn_exists() - check if a function is defined
#####################################################################
fn_exists() {
    declare -F "$1" &>/dev/null
}

#####################################################################
# 3) clr_layer() - (Use your latest version that preserves multi-word text)
#    Or keep your existing one if it works for you.
#####################################################################
clr_layer() {
    local CLR_ECHOSWITCHES="-e"
    local CLR_STACK=""
    local CLR_SWITCHES=""
    local ARGS=("$@")

    if [[ $# -eq 0 ]]; then
        return 0
    fi

    # Reverse the args array (so last typed is applied first)
    local REVERSED=()
    for (( i=${#ARGS[@]}-1; i>=0; i-- )); do
        REVERSED+=( "${ARGS[i]}" )
    done

    # We'll store each token separated by a delimiter that doesn't appear in text
    # ASCII 30 (Record Separator) is a decent choice. You can also use "||" or "<SEP>" if you prefer.
    local DELIM=$'\x1E'

    for ARG in "${REVERSED[@]}"; do
        if [[ "${ARG:0:1}" == "-" ]]; then
            [[ "$ARG" == "-n" ]] && CLR_ECHOSWITCHES="-en"
            CLR_SWITCHES+=" $ARG"
        else
            if fn_exists "$ARG" && [[ "$ARG" == clr_* ]]; then
                # If it's a color/attribute function, we need to rejoin the current CLR_STACK
                # into spaced text, call the function, then store the result as a single token.
                if [[ -n "$CLR_STACK" ]]; then
                    # Convert CLR_STACK from delimiter-based string to a normal spaced string
                    IFS="$DELIM" read -r -a stack_parts <<< "$CLR_STACK"
                    local current_text="${stack_parts[*]}"  # rejoin with space
                    current_text="$($ARG "$current_text")"
                    # Now store the entire colored text as a single token in CLR_STACK
                    CLR_STACK="$current_text"
                else
                    # If CLR_STACK was empty, just call the function on "" (rare)
                    CLR_STACK="$($ARG "")"
                fi
            else
                # Otherwise, treat it as plain text or numeric code, but store as one token
                if [[ -z "$CLR_STACK" ]]; then
                    CLR_STACK="$ARG"
                else
                    CLR_STACK="$ARG$DELIM$CLR_STACK"
                fi
            fi
        fi
    done

    # Now we parse CLR_STACK by $DELIM, not by spaces
    local items=()
    IFS="$DELIM" read -r -a items <<< "$CLR_STACK"

    # Separate numeric codes vs. text
    local CODES=()
    local TEXT_PARTS=()

    for part in "${items[@]}"; do
        if [[ "$part" == *";"* ]]; then
            # extended code "38;5;196" or combined "1;38;5;82"
            CODES+=("$part")
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            # plain numeric code 0..107
            CODES+=("$part")
        else
            TEXT_PARTS+=("$part")
        fi
    done

    local TEXT="${TEXT_PARTS[*]}"
    clr_escape "$CLR_ECHOSWITCHES" "$TEXT" "${CODES[@]}"
}

#####################################################################
# 4) clr_escape() - also supports extended codes
#####################################################################
clr_escape() {
    local echoswitches="$1"
    shift
    local text="$1"
    shift
    local codes=("$@")

    # Minimal check: if code has semicolon, skip numeric check.
    # Otherwise ensure 0..107 range. Adjust if you want to allow more.
    for code in "${codes[@]}"; do
        if [[ "$code" == *";"* ]]; then
            : # extended "38;5;..." or combined "1;38;5;196", skip
        else
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

    echo "$echoswitches" "$text"
}

#####################################################################
# 5) Color wrapper functions
#####################################################################
# Basic
clr_reset()           { clr_layer $CLR_RESET "$@";           }
clr_reset_underline() { clr_layer $CLR_RESET_UNDERLINE "$@"; }
clr_reset_reverse()   { clr_layer $CLR_RESET_REVERSE "$@";   }
clr_default()         { clr_layer $CLR_DEFAULT "$@";         }
clr_defaultb()        { clr_layer $CLR_DEFAULTB "$@";        }
clr_bold()            { clr_layer $CLR_BOLD "$@";            }
clr_underscore()      { clr_layer $CLR_UNDERSCORE "$@";      }
clr_reverse()         { clr_layer $CLR_REVERSE "$@";         }

# Newly added attribute wrappers:
clr_italic()          { clr_layer $CLR_ITALIC "$@";          }
clr_blink()           { clr_layer $CLR_BLINK "$@";           }

# 8 standard fg colors
clr_black()   { clr_layer $CLR_BLACK "$@";   }
clr_red()     { clr_layer $CLR_RED "$@";     }
clr_green()   { clr_layer "$CLR_GREEN" "$@";   }
clr_yellow()  { clr_layer $CLR_YELLOW "$@";  }
clr_blue()    { clr_layer $CLR_BLUE "$@";    }
clr_magenta() { clr_layer $CLR_MAGENTA "$@"; }
clr_cyan()    { clr_layer $CLR_CYAN "$@";    }
clr_white()   { clr_layer $CLR_WHITE "$@";   }

# 8 standard bg colors
clr_blackb()   { clr_layer $CLR_BLACKB "$@";   }
clr_redb()     { clr_layer $CLR_REDB "$@";     }
clr_greenb()   { clr_layer $CLR_GREENB "$@";   }
clr_yellowb()  { clr_layer $CLR_YELLOWB "$@";  }
clr_blueb()    { clr_layer $CLR_BLUEB "$@";    }
clr_magentab() { clr_layer $CLR_MAGENTAB "$@"; }
clr_cyanb()    { clr_layer $CLR_CYANB "$@";    }
clr_whiteb()   { clr_layer $CLR_WHITEB "$@";   }

# **Bright** fg
clr_bright_black()   { clr_layer $CLR_BRIGHT_BLACK "$@";   }
clr_bright_red()     { clr_layer $CLR_BRIGHT_RED "$@";     }
clr_bright_green()   { clr_layer $CLR_BRIGHT_GREEN "$@";   }
clr_bright_yellow()  { clr_layer $CLR_BRIGHT_YELLOW "$@";  }
clr_bright_blue()    { clr_layer $CLR_BRIGHT_BLUE "$@";    }
clr_bright_magenta() { clr_layer $CLR_BRIGHT_MAGENTA "$@"; }
clr_bright_cyan()    { clr_layer $CLR_BRIGHT_CYAN "$@";    }
clr_bright_white()   { clr_layer $CLR_BRIGHT_WHITE "$@";   }

# **Bright** bg
clr_bright_blackb()   { clr_layer $CLR_BRIGHT_BLACKB "$@";   }
clr_bright_redb()     { clr_layer $CLR_BRIGHT_REDB "$@";     }
clr_bright_greenb()   { clr_layer $CLR_BRIGHT_GREENB "$@";   }
clr_bright_yellowb()  { clr_layer $CLR_BRIGHT_YELLOWB "$@";  }
clr_bright_blueb()    { clr_layer $CLR_BRIGHT_BLUEB "$@";    }
clr_bright_magentab() { clr_layer $CLR_BRIGHT_MAGENTAB "$@"; }
clr_bright_cyanb()    { clr_layer $CLR_BRIGHT_CYANB "$@";    }
clr_bright_whiteb()   { clr_layer $CLR_BRIGHT_WHITEB "$@";   }

#####################################################################
# 6) 256-color functions
#####################################################################
clr_256fg() {
    local code="$1"
    shift
    if [[ ! "$code" =~ ^[0-9]{1,3}$ ]] || (( code < 0 || code > 255 )); then
        echo "Invalid 256 FG code: $code" >&2
        return 1
    fi
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
# 7) clr_dump() - show standard, bright, plus 256 color table
#####################################################################
clr_dump() {
    echo "==== 16-Color / 8-Color + Bright Combinations ===="
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

            local reset="${CLR_ESC}${CLR_RESET}m"
            local base="${CLR_ESC}${fg_code};${bg_code}m"
            local bold="${CLR_ESC}${CLR_BOLD};${fg_code};${bg_code}m"
            local under="${CLR_ESC}${CLR_UNDERSCORE};${fg_code};${bg_code}m"
            local reverse="${CLR_ESC}${CLR_REVERSE};${fg_code};${bg_code}m"
            local italic="${CLR_ESC}${CLR_ITALIC};${fg_code};${bg_code}m"
            local blink="${CLR_ESC}${CLR_BLINK};${fg_code};${bg_code}m"

            # We'll print everything on one line:
            printf "%bText(Norm)%b "   "$base"    "$reset"
            printf "%b(Bold)%b "       "$bold"    "$reset"
            printf "%b(Undr)%b "       "$under"   "$reset"
            printf "%b(Rev)%b "        "$reverse" "$reset"
            printf "%b(Ital)%b "       "$italic"  "$reset"
            printf "%b(Blink)%b "      "$blink"   "$reset"
            printf " - %s on %s\n" "$fg_name" "$bg_name"
        done
    done

    echo
    echo "==== 256-Color Foreground Table ===="
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
# 8) Main entry point
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
