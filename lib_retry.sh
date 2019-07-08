#!/bin/bash

function include_dependencies {
    source /usr/lib/lib_bash/lib_color.sh
}

# we need to do this in a function otherwise parameter {@} will be passed !
# and we need to do it here, before another library overwrites the function include_dependencies
include_dependencies


function fail {
  clr_bold clr_red "${1}" >&2
  exit 1
}

function nofail {
  clr_bold clr_red "${1}" >&2
  exit 0
}


function retry {
  local n=1
  local max=5
  local delay=5
  while true; do
	my_command="${@}"
    "$@" && break || {
      if [[ ${n} -lt ${max} ]]; then
        ((n++))
        clr_bold clr_red "Command \"${my_command}\" failed. Attempt ${n}/${max}:"
        sleep ${delay};
      else
        fail "The command \"${my_command}\" has failed after ${n} attempts."
      fi
    }
  done
}


function retry_nofail {
  local n=1
  local max=5
  local delay=5
  while true; do
	my_command="${@}"
    "$@" && break || {
      if [[ ${n} -lt ${max} ]]; then
        ((n++))
        clr_bold clr_red "Command \"${my_command}\" failed. Attempt ${n}/${max}:"
        sleep ${delay};
      else
        nofail "The command \"${my_command}\" has failed after ${n} attempts, continue with exit code 0"
      fi
    }
  done
}



## make it possible to call functions without source include
# Check if the function exists (bash specific)
if [[ ! -z "$1" ]]
    then
        if declare -f "${1}" > /dev/null
        then
          # call arguments verbatim
          "$@"
        else
          # Show a helpful error
          function_name="${1}"
          library_name="${0}"
          fail "\"${function_name}\" is not a known function name of \"${library_name}\""
        fi
	fi
