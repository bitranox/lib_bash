#!/bin/bash


# call the update script if nout sourced - disabled here because we call this A LOT !!
# if [[ "${0}" == "${BASH_SOURCE}" ]] && [[ -d "${BASH_SOURCE%/*}" ]]; then "${BASH_SOURCE%/*}"/install_or_update.sh else "${PWD}"/install_or_update.sh ; fi


function get_my_dir {
    local mydir
    mydir="${BASH_SOURCE%/*}"
    if [[ ! -d "$mydir" ]]; then mydir="$PWD"; fi
    echo "$mydir"
}

function include_dependencies {
    local mydir
    mydir="$(get_my_dir)"
    source "$mydir/lib_helpers.sh"
}

include_dependencies


# This directive only applies to this function
# shellcheck disable=SC2015
function retry {
  local n max delay command_str
  n=1
  max=5
  delay=5
  while true; do
	command_str="${*}"
    "$@" && break || {
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
    "$@" && break || {
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
call_function_from_commandline "${0}" "${@}"
