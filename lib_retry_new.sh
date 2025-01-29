#!/bin/bash
set -o errexit -o nounset -o pipefail

# Generic retry function
retry() {
  local n max delay log_func cmd_status
  local -Ar error_messages=(
    [1]="General error"
    [2]="Misuse of shell builtins"
    [126]="Command invoked cannot execute"
    [127]="Command not found"
    [130]="Script terminated by Control-C"
  )

  n=1
  max=5
  delay=5
  log_func="log_err"
  cmd_status=0

  # Parse Options
  while getopts "n:d:l:" opt; do
    case $opt in
        n) max="$OPTARG" ;;
        d) delay="$OPTARG" ;;
        l) log_func="$OPTARG" ;;
        :)
          echo "lib_retry: Option -$OPTARG requires an argument" >&2
          return 1
          ;;
        \?)
          echo "lib_retry: Usage: retry [-n <max_attempts>] [-d <delay>] [-l <log_function>] <command> [args ...]" >&2
          return 1
          ;;
    esac
  done
  shift $((OPTIND - 1))

  # Validate log function exists
  if ! declare -F "$log_func" >/dev/null; then
    echo "lib_retry: Invalid log function: $log_func" >&2
    return 1
  fi

  # Input Validation
  if ! [[ "$max" =~ ^[0-9]+$ ]] || [[ "$max" -le 0 ]]; then
    ${log_func} "lib_retry: Invalid max attempts: $max"
    return 1
  fi

  if ! [[ "$delay" =~ ^[0-9]+$ ]] || [[ "$delay" -le 0 ]]; then
    ${log_func} "lib_retry: Invalid delay: $delay"
    return 1
  fi

  if [[ $# -eq 0 ]] ; then
    ${log_func} "lib_retry: No command specified"
    return 1
  fi

  while true; do
    "${@}"
    cmd_status=$?

    if [[ $cmd_status -eq 0 ]]; then
      break
    else
      if [[ ${n} -lt ${max} ]]; then
          if [[ -v error_messages[$cmd_status] ]] ; then
            printf -v cmd_str '%q ' "$@"
            ${log_func} "lib_retry: Command ${cmd_str%% } failed with exit code $cmd_status: ${error_messages[$cmd_status]}. Attempt ${n}/${max}:"
          else
            printf -v cmd_str '%q ' "$@"
            ${log_func} "lib_retry: Command ${cmd_str%% } failed with exit code $cmd_status. Attempt ${n}/${max}:"
          fi
        ((n++))
        local backoff=$(( delay * (2 ** (n-1)) ))
        sleep "$backoff"
      else
        if [[ -v error_messages[$cmd_status] ]] ; then
          printf -v cmd_str '%q ' "$@"
          ${log_func} "lib_retry: The command ${cmd_str%% } failed after ${n} attempts with exit code $cmd_status: ${error_messages[$cmd_status]}."
        else
          printf -v cmd_str '%q ' "$@"
          ${log_func} "lib_retry: The command ${cmd_str%% } failed after ${n} attempts with exit code $cmd_status."
        fi
         break
      fi
    fi
  done

  return $cmd_status
}

# Example usage:
# retry -n 3 -d 2 ls -l /invalid_path
# if [[ $? -ne 0 ]] ; then echo failed with $? ; else echo success ; fi
# retry -n 3 -d 2  -l log_my_own_function ls -l /invalid_path
# if [[ $? -ne 0 ]] ; then echo failed with $? ; else echo success ; fi
# retry -n 3 -d 2 thiscommanddoesnotexist
# if [[ $? -ne 0 ]] ; then echo failed with $? ; else echo success ; fi
# retry -n 3 -d 2 ls thisfiledoesnotexist
# if [[ $? -ne 0 ]] ; then echo failed with $? ; else echo success ; fi
