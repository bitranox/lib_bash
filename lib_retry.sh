#!/bin/bash
# lib_retry.sh — Exponential backoff retry helper for Bash
#
# Purpose:
# - Provides `retry` to re-run a command with exponential backoff.
# - Supports configurable attempts, base delay, and pluggable logger function.
# - Honors non-retryable exit codes with environment override.
#
# Usage:
# - `retry -n 3 -d 2 -- cmd args...`
# - Default logger is `log_err` if available, otherwise a safe stderr fallback.
#
# Notes:
# - Uses built-in `getopts` (no external getopt dependency).
# - Strict mode only when executed directly, not when sourced.

# For detection if the script is sourced correctly
# shellcheck disable=SC2034
LIB_RETRY_LOADED=true

_lib_retry_is_in_script_mode() {
  case "${BASH_SOURCE[0]}" in
    "${0}") return 0 ;;  # script mode
    *)      return 1 ;;
  esac
}

# --- only in script mode ---
if _lib_retry_is_in_script_mode; then
  # Strict mode & traps only when run directly
  set -Eeuo pipefail
  IFS=$'\n\t'
  umask 022
  # shellcheck disable=SC2154
  trap 'ec=$?; echo "ERR $ec at ${BASH_SOURCE[0]}:${LINENO}: ${BASH_COMMAND}" >&2' ERR
fi


# Fallback logger for standalone usage (stderr only)
_lib_retry_fallback_logger() {
    printf '%s\n' "$*" >&2
}


check_dependencies() {
    # Pass one or more commands to check, e.g.: check_dependencies "getopt" "curl"
    local -a missing_cmds=()

    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_cmds+=("$cmd")
        fi
    done

    if [ "${#missing_cmds[@]}" -ne 0 ]; then
        echo "Error: The following required commands are not installed: ${missing_cmds[*]}" >&2
        exit 127
    fi
}

:<<'DOC'
Retry command with exponential backoff

Options:
  -n MAX_ATTEMPTS  Number of retry attempts (default: 5)
  -d RETRY_DELAY   Base delay in seconds (default: 5)
  -l LOG_FUNC      Logger function (default: log_err)

Non-retryable errors: 126 (Permission denied), 127 (Command not found), 130 (User interrupt)
Override non-retryable errors with RETRY_NON_RETRYABLE environment array

Usage:
  retry [options] -- command [args...]
DOC


retry() {
    local -i max_attempts=5 retry_delay=5 attempt=1
    local log_func="log_err"
    local -a non_retryable=(126 127 130)
    local -Ar error_messages=(
        [1]="General error"
        [2]="Misuse of shell builtins"
        [126]="Command invoked cannot execute"
        [127]="Command not found"
        [130]="Script terminated by Control-C"
    )

    # Parse options using built-in getopts (no external dependency)
    local OPTIND opt
    while getopts ":n:d:l:" opt; do
        case ${opt} in
            n) max_attempts=${OPTARG} ;;
            d) retry_delay=${OPTARG} ;;
            l) log_func=${OPTARG} ;;
            :) echo "lib_retry: Option -${OPTARG} requires an argument" >&2; return 1 ;;
            \?) echo "lib_retry: Invalid option: -${OPTARG}" >&2; return 1 ;;
        esac
    done
    shift $((OPTIND - 1))
    # Respect optional double-dash separator if provided
    if [[ ${1-} == "--" ]]; then
        shift
    fi

    # Provide a safe default logger if not available and default is used
    if [[ "${log_func}" == "log_err" ]] && ! type -t log_err >/dev/null 2>&1; then
        log_func="_lib_retry_fallback_logger"
    fi

    # Validate parameters before using logger (accept function, builtin, or external)
    if ! type -t "${log_func}" >/dev/null 2>&1; then
        echo "lib_retry: Invalid log function: ${log_func}" >&2
        return 1
    fi

    if (($# == 0)); then
        "${log_func}" "lib_retry: No command specified" >&2
        return 1
    fi

    if ! [[ "${max_attempts}" =~ ^[0-9]+$ ]] || (( max_attempts < 1 )); then
        "${log_func}" "lib_retry: Invalid max attempts: ${max_attempts}" >&2
        return 1
    fi

    if ! [[ "${retry_delay}" =~ ^[0-9]+$ ]] || (( retry_delay < 1 )); then
        "${log_func}" "lib_retry: Invalid delay: ${retry_delay}" >&2
        return 1
    fi


    # Apply environment overrides for non-retryable errors
    [[ -v RETRY_NON_RETRYABLE ]] && non_retryable=("${RETRY_NON_RETRYABLE[@]}")

    # Retry loop
    local -i cmd_status=0
    while ((attempt <= max_attempts)); do
        # Preserve caller's errexit (-e) state while capturing command status
        local _had_e=0
        case $- in *e*) _had_e=1;; esac
        set +e
        "$@"
        cmd_status=$?
        (( _had_e )) && set -e

        # Check if error is non-retryable
        local -i is_non_retryable=0
        for code in "${non_retryable[@]}"; do
            ((cmd_status == code)) && { is_non_retryable=1; break; }
        done

        if ((is_non_retryable)); then
            "${log_func}" "lib_retry: Command failed with non-retryable error: ${*} (exit: ${cmd_status})"
            return "${cmd_status}"
        fi

        if ((cmd_status == 0)); then
            return 0
        fi

        # Prepare error message
        local error_msg="lib_retry: Command failed: ${*} (exit: ${cmd_status})"
        [[ -v error_messages[${cmd_status}] ]] &&
            error_msg+=" - ${error_messages[${cmd_status}]}"

        # Calculate backoff with cap
        local -i max_backoff=300
        local -i backoff=$(( retry_delay * (1 << (attempt - 1)) ))
        (( backoff > max_backoff )) && backoff=${max_backoff}

        if ((attempt < max_attempts)); then
            "${log_func}" "${error_msg}. Retry ${attempt}/${max_attempts} in ${backoff}s"
            sleep "${backoff}"
        else
            "${log_func}" "${error_msg} (no more retries)"
            return "${cmd_status}"
        fi
        ((attempt++))
    done

    return "${cmd_status}"
}
