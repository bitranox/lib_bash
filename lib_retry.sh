#!/bin/bash

# This directive only applies to this function
# shellcheck disable=SC2015
function retry {
  local n max delay command_str
  n=1
  max=5
  delay=5
  while true; do
	command_str="${*}"
    eval "${command_str}" && break || {
      if [[ ${n} -lt ${max} ]]; then
        ((n++))
        log_err "Command \"${command_str}\" failed. Attempt ${n}/${max}:"
        sleep ${delay};
      else
        log_err "The command \"${command_str}\" has failed after ${n} attempts."
        return 1
      fi
    }
  done
}


# This directive only applies to this function
# shellcheck disable=SC2015
function retry_nofail {
  local n max delay command_str
  n=1
  max=5
  delay=5
  while true; do
	command_str="${*}"
    eval "${command_str}" && break || {
      if [[ ${n} -lt ${max} ]]; then
        ((n++))
        log_err "Command \"${command_str}\" failed. Attempt ${n}/${max}: - no panic, we will continue after the last attempt !"
        sleep ${delay};
      else
        log_err "The command \"${command_str}\" has failed after ${n} attempts, continue ..."
        break
      fi
    }
  done
}
