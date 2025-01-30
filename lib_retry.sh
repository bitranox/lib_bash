#!/bin/bash
# lib_retry.sh
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

set -o errexit -o nounset -o pipefail

retry() {
    local -i max_attempts=5 retry_delay=5 attempt=1
    local log_func="log_err"
    local -ar non_retryable=(126 127 130)
    local -Ar error_messages=(
        [1]="General error"
        [2]="Misuse of shell builtins"
        [126]="Command invoked cannot execute"
        [127]="Command not found"
        [130]="Script terminated by Control-C"
    )

    # Parse options
    local opts
    opts=$(getopt -o n:d:l: -- "$@") || {
        echo "lib_retry: Usage error" >&2
        return 1
    }
    eval set -- "$opts"

    while true; do
        case $1 in
            -n) max_attempts=$2; shift 2 ;;
            -d) retry_delay=$2; shift 2 ;;
            -l) log_func=$2; shift 2 ;;
            --) shift; break ;;
            *) echo "lib_retry: Invalid option" >&2; return 1 ;;
        esac
    done

    # Validate parameters before using logger
    if ! declare -F "${log_func}" &>/dev/null; then
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
        set +e
        "$@"
        cmd_status=$?
        set -e

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
        local -i backoff=$(( retry_delay * 2#1 << (attempt-1) ))
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
