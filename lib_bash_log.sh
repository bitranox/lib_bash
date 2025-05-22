#!/bin/bash

set -eEuo pipefail
trap 'echo "Script failed at line $LINENO with exit code $?" >&2' ERR

# ------------------------------------------------------------------------------
# Function: _set_default_logfiles
# Purpose : Define default log file paths and initialize global log variables.
# Usage   : _set_default_logfiles            # Sets only if not already defined.
#         : _set_default_logfiles "RESET"    # Force reset of all log paths.
#
# Description:
#   Initializes four log file variables depending on user privilege:
#     - <prefix>/<script>.log          → Main log file
#     - <prefix>/<script>_tmp.log      → Temporary session log
#     - <prefix>/<script>_err.log      → Error-only log file
#     - <prefix>/<script>_err_tmp.log  → Temporary session error log
#
#   Temporary logs are automatically registered for cleanup.
#
# Dependencies:
#   - get_script_stem (from lib_bash)
#   - is_root (from lib_bash)
#   - register_temppath
# ------------------------------------------------------------------------------

_set_default_logfiles() {
    local reset="${1:-}"
    local script_stem log_prefix

    script_stem=$(get_script_stem)

    if is_root; then
        log_prefix="/var/log/lib_bash"
    else
        log_prefix="${HOME}/log/lib_bash"
    fi

    local main_log="${log_prefix}/${script_stem}.log"
    local tmp_log="${log_prefix}/${script_stem}_tmp.log"
    local err_log="${log_prefix}/${script_stem}_err.log"
    local err_tmp_log="${log_prefix}/${script_stem}_err_tmp.log"

    if [[ "${reset}" == "RESET" ]]; then
        LIB_BASH_LOGFILE="${main_log}"
        LIB_BASH_LOGFILE_TMP="${tmp_log}"
        LIB_BASH_LOGFILE_ERR="${err_log}"
        LIB_BASH_LOGFILE_ERR_TMP="${err_tmp_log}"
    else
        : "${LIB_BASH_LOGFILE:="${main_log}"}"
        : "${LIB_BASH_LOGFILE_TMP:="${tmp_log}"}"
        : "${LIB_BASH_LOGFILE_ERR:="${err_log}"}"
        : "${LIB_BASH_LOGFILE_ERR_TMP:="${err_tmp_log}"}"
    fi

    register_temppath "${LIB_BASH_LOGFILE_TMP}"
    register_temppath "${LIB_BASH_LOGFILE_ERR_TMP}"
}


# ------------------------------------------------------------------------------
# Function: _set_default_logfile_colors
# Purpose : Initialize or reset terminal color settings for log levels.
# Usage   : _set_default_logfile_colors            # Sets only if unset
#         : _set_default_logfile_colors "RESET"    # Force reset of all
#
# Description:
#   Defines default color functions for output levels (log, error, warn, debug).
#
# Dependencies:
#   - Terminal color functions (e.g., clr_green, clr_bold)
# ------------------------------------------------------------------------------

_set_default_logfile_colors() {
    local reset="${1:-}"

    local default_clr="clr_green"
    local default_bold="clr_bold clr_green"
    local default_err="clr_bold clr_cyan"
    local default_warn="clr_bold clr_yellow"
    local default_debug="clr_bold clr_magentab clr_yellow"

    if [[ "${reset}" == "RESET" ]]; then
        _LOG_COLOR="$default_clr"
        _LOG_COLOR_BOLD="$default_bold"
        _LOG_COLOR_ERR="$default_err"
        _LOG_COLOR_WARN="$default_warn"
        _LOG_COLOR_DEBUG="$default_debug"
    else
        : "${_LOG_COLOR:=$default_clr}"
        : "${_LOG_COLOR_BOLD:=$default_bold}"
        : "${_LOG_COLOR_ERR:=$default_err}"
        : "${_LOG_COLOR_WARN:=$default_warn}"
        : "${_LOG_COLOR_DEBUG:=$default_debug}"
    fi
}


# ------------------------------------------------------------------------------
# Function: _set_default_debugmode
# Purpose : Initialize or reset debug mode variable to "OFF".
# Usage   : _set_default_debugmode            # Sets if unset
#         : _set_default_debugmode "RESET"    # Forces reset to "OFF"
# ------------------------------------------------------------------------------

_set_default_debugmode() {
    local reset="${1:-}"
    local debug_mode="OFF"

    if [[ "${reset}" == "RESET" ]]; then
        LIB_BASH_DEBUG_MODE="${debug_mode}"
    else
        : "${LIB_BASH_DEBUG_MODE:="${debug_mode}"}"
    fi
}


# ------------------------------------------------------------------------------
# Function: _create_log_dir
# Purpose : Ensure the directory of a given logfile exists (create if needed).
# Usage   : _create_log_dir "/full/path/to/logfile.log"
#
# Dependencies:
#   - log_err (logs and exits on failure)
# ------------------------------------------------------------------------------

_create_log_dir() {
    local logfile="${1}"
    local log_dir
    log_dir=$(dirname "${logfile}")

    if [[ ! -d "${log_dir}" ]]; then
        if ! mkdir -p "${log_dir}"; then
            echo "Failed to create log directory: ${log_dir}"
            exit 1
        fi
    fi
}


# ------------------------------------------------------------------------------
# Function: _log
# Purpose : Internal function to log messages to terminal and/or files.
# Usage   : Called by wrapper functions like log, log_err, etc.
#
# Parameters:
#   $1  - message
#   $2  - options ("bold", "NO_TTY")
#   $3  - color_funcs_str (e.g., "clr_bold clr_red")
#   $4  - log_file
#   $5  - log_file_tmp
#   $6  - log_file_err
#   $7  - log_file_err_tmp
#   $8  - log level tag (e.g., "[LOG]")
#   $9  - icon (e.g., "✅")
#
# Dependencies:
#   - clr_* functions
#   - _create_log_dir
# ------------------------------------------------------------------------------

_log() {
    local message="${1:-"no message passed"}"
    local options="${2:-}"
    local color_funcs_str="${3:-}"
    local log_file="${4:-}"
    local log_file_tmp="${5:-}"
    local log_file_err="${6:-}"
    local log_file_err_tmp="${7:-}"
    local level="${8:-}"
    local icon="${9:-}"
    local logline

    if [[ -n "${log_file}" ]]; then _create_log_dir "${log_file}"; fi
    if [[ -n "${log_file_tmp}" ]]; then _create_log_dir "${log_file_tmp}"; fi
    if [[ -n "${log_file_err}" ]]; then _create_log_dir "${log_file_err}"; fi
    if [[ -n "${log_file_err_tmp}" ]]; then _create_log_dir "${log_file_err_tmp}"; fi

    local logprefix
    logprefix="$(date '+%Y-%m-%d %H:%M:%S') - $(whoami)@$(hostname -s) ${level}:"

    IFS=$'\n' read -rd '' -a lines <<< "${message}" || true
    for line in "${lines[@]}"; do
        if [[ "${options}" != *NO_TTY* ]]; then
            local formatted_line="${logprefix} ${icon} ${line}"
            local -a color_funcs=()
            IFS=' ' read -ra color_funcs <<< "${color_funcs_str}"
            for func in "${color_funcs[@]}"; do
                if declare -f "${func}" > /dev/null; then
                    formatted_line="$("${func}" "${formatted_line}")"
                else
                    echo "Missing color function: ${func}" >&2
                fi
            done
            echo -e "${formatted_line}"
        fi

        logline="${logprefix} ${line}"
        if [[ -n "${log_file}" ]]; then echo "${logline}" >> "${log_file}"; fi
        if [[ -n "${log_file_tmp}" ]]; then echo "${logline}" >> "${log_file_tmp}"; fi
        if [[ -n "${log_file_err}" ]]; then echo "${logline}" >> "${log_file_err}"; fi
        if [[ -n "${log_file_err_tmp}" ]]; then echo "${logline}" >> "${log_file_err_tmp}"; fi
    done
}


# ------------------------------------------------------------------------------
# Public Logging Interfaces
# ------------------------------------------------------------------------------

log() {
    if [ -z "${1:-}" ]; then
        log_warn "lib_bash_log: log(): no message passed"
        return 1
    fi
    local message="${1:-}"
    local options="${2:-}"
    local color_funcs_str="${_LOG_COLOR:-clr_green}"
    [[ "${options}" == *bold* ]] && color_funcs_str="${_LOG_COLOR_BOLD:-clr_bold clr_green}"
    _log "${message}" "${options}" "${color_funcs_str}" "${LIB_BASH_LOGFILE}" "${LIB_BASH_LOGFILE_TMP}" "" "" "[LOG]" "ℹ️"
    return 0
}

log_ok() {
    if [ -z "${1:-}" ]; then
        log_warn "lib_bash_log: log(): no message passed"
        return 1
    fi
    local message="${1:-}"
    local options="${2:-}"
    local color_funcs_str="${_LOG_COLOR:-clr_green}"
    [[ "${options}" == *bold* ]] && color_funcs_str="${_LOG_COLOR_BOLD:-clr_bold clr_green}"
    _log "${message}" "${options}" "${color_funcs_str}" "${LIB_BASH_LOGFILE}" "${LIB_BASH_LOGFILE_TMP}" "" "" "[LOG]" "✔️"
    return 0
}

log_wrench() {
    if [ -z "${1:-}" ]; then
        log_warn "lib_bash_log: log(): no message passed"
        return 1
    fi
    local message="${1:-}"
    local options="${2:-}"
    local color_funcs_str="${_LOG_COLOR:-clr_green}"
    [[ "${options}" == *bold* ]] && color_funcs_str="${_LOG_COLOR_BOLD:-clr_bold clr_green}"
    _log "${message}" "${options}" "${color_funcs_str}" "${LIB_BASH_LOGFILE}" "${LIB_BASH_LOGFILE_TMP}" "" "" "[LOG]" "🔧"
    return 0
}

log_warn() {
    if [ -z "${1:-}" ]; then
        log_warn "lib_bash_log: log_warn: no message passed"
        return 1
    fi
    local message="${1:-}"
    local options="${2:-}"
    local color_funcs_str="${_LOG_COLOR_WARN:-clr_bold clr_yellow}"
    _log "${message}" "${options}" "${color_funcs_str}" "${LIB_BASH_LOGFILE}" "${LIB_BASH_LOGFILE_TMP}" "" "" "[WRN]" "⚠️ "
    return 0
}

log_err() {
    if [ -z "${1:-}" ]; then
        log_warn "lib_bash_log: log_err: no message passed"
        return 1
    fi
    local message="${1:-}"
    local options="${2:-}"
    local color_funcs_str="${_LOG_COLOR_ERR:-clr_bold clr_cyan}"
    _log "${message}" "${options}" "${color_funcs_str}" "${LIB_BASH_LOGFILE}" "${LIB_BASH_LOGFILE_TMP}" "${LIB_BASH_LOGFILE_ERR}" "${LIB_BASH_LOGFILE_ERR_TMP}" "[ERR]" "❌"
    return 0
}

log_debug() {
    if [ -z "${1:-}" ]; then
        log_warn "lib_bash_log: log_debug(): no message passed"
        return 1
    fi
    if [[ "${LIB_BASH_DEBUG_MODE}" == "OFF" ]]; then return 0; fi
    local message="${1:-}"
    local options="${2:-}"
    local color_funcs_str="${_LOG_COLOR_DEBUG:-clr_bold clr_magentab clr_yellow}"
    _log "${message}" "${options}" "${color_funcs_str}" "${LIB_BASH_LOGFILE}" "${LIB_BASH_LOGFILE_TMP}" "" "" "[DBG]" "🐞"
    return 0
}


# ------------------------------------------------------------------------------
# Function: logc
# Purpose : Run a command, log its output live, log errors if any.
# Usage   : logc <command> [args...]
# ------------------------------------------------------------------------------

logc() {
    local exit_code output has_output
    exec 3>&1
    output=$("$@" 2>&1 | tee >(cat >&3))
    exit_code=${PIPESTATUS[0]}
    exec 3>&-

    [[ -n "$output" ]] && has_output=true || has_output=false

    if $has_output; then
        if (( exit_code == 0 )); then
            log "${output}" "NO_TTY"
        else
            log_err "${output}" "NO_TTY"
        fi
    else
        (( exit_code != 0 )) && log_err "exitcode: ${exit_code}"
    fi
    return "${exit_code}"
}


# ------------------------------------------------------------------------------
# Function: logc_err
# Purpose : Always log command output as error, regardless of exit code.
# Usage   : logc_err <command> [args...]
# ------------------------------------------------------------------------------

logc_err() {
    local exit_code output
    exec 3>&1
    output=$("$@" 2>&1 | tee >(cat >&3))
    exit_code=${PIPESTATUS[0]}
    exec 3>&-
    log_err "${output}" "NO_TTY"
    (( exit_code != 0 )) && log_err "exitcode: ${exit_code}"
    return "${exit_code}"
}


# ------------------------------------------------------------------------------
# Initialize Logging System
# ------------------------------------------------------------------------------

_set_default_logfiles RESET
_set_default_logfile_colors RESET
_set_default_debugmode RESET
