#!/bin/bash

# Generic retry function
retry() {
  local n max delay log_func cmd_status
  n=1
  max=5
  delay=5
  log_func="log_err"
  cmd_status=0 # Initialize command status to success

  # Error code mappings
  declare -A error_messages
  error_messages[1]="General error"
  error_messages[2]="Misuse of shell builtins"
  error_messages[126]="Command invoked cannot execute"
  error_messages[127]="Command not found"
  error_messages[130]="Script terminated by Control-C"

  # Parse Options
  while getopts "n:d:l:" opt; do
    case $opt in
        n) max="$OPTARG" ;;
        d) delay="$OPTARG" ;;
        l) log_func="$OPTARG" ;;
        \?)
          echo "lib_retry: Usage: retry [-n <max_attempts>] [-d <delay>] [-l <log_function>] <command> [args ...]" >&2
          return 1
          ;;
    esac
  done
  shift $((OPTIND - 1))

  # Input Validation (simplified)
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
    # Execute the command, store exit code in cmd_status
    "${@}"
    cmd_status=$?

    if [[ $cmd_status -eq 0 ]]; then
      break # Command success, exit retry loop
    else
      if [[ ${n} -lt ${max} ]]; then
          # Check for specific error code
          if [[ -v error_messages[$cmd_status] ]] ; then
            ${log_func} "lib_retry: Command \"$@\" failed with exit code $cmd_status: ${error_messages[$cmd_status]}. Attempt ${n}/${max}:"
          else
            ${log_func} "lib_retry: Command \"$@\" failed with exit code $cmd_status. Attempt ${n}/${max}:"
          fi
        ((n++))
        sleep ${delay};
      else
        if [[ -v error_messages[$cmd_status] ]] ; then
          ${log_func} "lib_retry: The command \"$@\" failed after ${n} attempts with exit code $cmd_status: ${error_messages[$cmd_status]}."
        else
           ${log_func} "lib_retry: The command \"$@\" failed after ${n} attempts with exit code $cmd_status."
        fi
         break # Exit retry loop after max attempts
      fi
    fi
  done

  return $cmd_status # Return the exit code of the last attempt
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
