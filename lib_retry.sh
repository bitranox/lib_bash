#!/bin/bash

function include_dependencies {
    source /usr/local/lib_bash/lib_color.sh
}

include_dependencies


function assert_equal {
	# $1 : test
	# $2 : expected
	local test="${1}"
	local expected="${2}"
	local result=$(eval ${1})

	if [[ "${result}" != "${expected}" ]]; then
		clr_reverse clr_cyan  "File     : $0"
		clr_cyan "Test     : ${test}${IFS}Result   : ${result}${IFS}Expected : ${expected}"
		clr_red "***********************************************************************************************"
	fi
}


function fail {
  clr_bold clr_red "${1}" >&2
  exit 1
}


function nofail {
  clr_bold clr_red "${1}"
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
        clr_bold clr_red "Command \"${my_command}\" failed. Attempt ${n}/${max}: - no panic, we will continue after the last attempt !"
        sleep ${delay};
      else
        nofail "The command \"${my_command}\" has failed after ${n} attempts, continue ..."
        break
      fi
    }
  done
}


function check_if_bash_function_is_declared {
    # $1 : function name
    local function_name="${1}"
    declare -F ${function_name} &>/dev/null && echo "True" || echo "False"
}


function call_function_from_commandline {
    # $1 : library_name ("${0}")
    # $2 : function_name ("${1}")
    # $3 : call_args ("${@}")
    local library_name="${1}"
    local function_name="${2}"
    local call_args_array=("${@}")

    if [[ ! -z ${function_name} ]]; then
        if [[ $(check_if_bash_function_is_declared "${function_name}") == "True" ]]; then
            ${call_args_array[@]:1}
        else
            fail "${function_name} is not a known function name of ${library_name}"
        fi
    fi
}



function tests {
	clr_green "no tests in ${0}"
}

## make it possible to call functions without source include
call_function_from_commandline "${0}" "${@}"
