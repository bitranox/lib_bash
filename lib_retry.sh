#!/bin/bash

function default_actions {
sudo_askpass="$(command -v ssh-askpass)"
export SUDO_ASKPASS="${sudo_askpass}"
export NO_AT_BRIDGE=1  # get rid of ssh-askpass:25930 dbind-WARNING
}
default_actions


function include_dependencies {
    local my_dir
    # shellcheck disable=SC2164
    my_dir="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"  # this gives the full path, even for sourced scripts
    source "${my_dir}/lib_color.sh"
}

# This directive only applies to this function
# shellcheck disable=SC2015
function retry {
  local n max delay command_str
  n=1
  max=5
  delay=5
  while true; do
	command_str="${*}"
    # ${@} && break || {
    eval "${command_str}" && break || {
      if [[ ${n} -lt ${max} ]]; then
        ((n++))
        clr_bold clr_red "Command \"${command_str}\" failed. Attempt ${n}/${max}:"
        sleep ${delay};
      else
        fail "The command \"${command_str}\" has failed after ${n} attempts."
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
	# ${@} && break || {
    eval "${command_str}" && break || {
      if [[ ${n} -lt ${max} ]]; then
        ((n++))
        clr_bold clr_red "Command \"${command_str}\" failed. Attempt ${n}/${max}: - no panic, we will continue after the last attempt !"
        sleep ${delay};
      else
        nofail "The command \"${command_str}\" has failed after ${n} attempts, continue ..."
        break
      fi
    }
  done
}

## make it possible to call functions without source include
include_dependencies
call_function_from_commandline "${0}" "${@}"
