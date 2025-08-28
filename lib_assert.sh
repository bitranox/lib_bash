#!/bin/bash
# shellcheck disable=SC2155

function assert_equal {
	# $1 : command
	# $2 : expected
	local command expected result

	command="${1}"
	expected="${2}"

  # shellcheck disable=SC2034
  result=$(get_result_as_string "${command}")

  # report if failed
	if [[ "${result}" != "${expected}" ]]; then
	    create_assert_failed_message "${command}" "\"${expected}\"" "\"${result}\"" "assert_equal"
    fi
}

function assert_contains {
	# $1 : command
	# $2 : expected
	local command expected result
	command="${1}"
	expected="${2}"

  # shellcheck disable=SC2034
  result=$(get_result_as_string "${command}")

  # report if failed
	if [[ "${result}" != *"${expected}"* ]]; then
	    create_assert_failed_message "${command}" "\"*${expected}*\"" "\"${result}\"" "assert_contains"
	    fi
}

function assert_return_code {
	# $1 : command
	# $2 : expected
	local command expected result
	command="${1}"
	expected="${2}"

  # shellcheck disable=SC2034
  result=$(get_returncode_as_string "${command}")

  # report if failed
	if [[ "${result}" -ne "${expected}" ]]; then
	    create_assert_failed_message "${command}" "return code = ${expected}" "return code = ${result}" "assert_return_code"
    fi
}

function assert_pass {
	# $1 : command
	local command result
	command="${1}"

  # shellcheck disable=SC2034
  result=$(get_returncode_as_string "${command}")

  # report if failed
  if [[ "${result}" != "0" ]]; then
	    create_assert_failed_message "${command}" "return code = 0" "return code = ${result}" "assert_pass"
    fi
}


function assert_fail {
	# $1 : command
	local command result
	command="${1}"

  # shellcheck disable=SC2034
  result=$(get_returncode_as_string "${command}")

  # report if failed
  if [[ "${result}" == "0" ]]; then
      create_assert_failed_message "${command}" "return code > 0" "return code = ${result}" "assert_fail"
  fi
}


function check_assert_command_defined {
  	# $1 : test_command
  	# $2 : expected
    local test_command="${1}"
    local expected="${2}"
    local result
    local function_name
    function_name="$(echo "${test_command}" | cut -d " " -f 1)"

    if ! is_valid_command "${function_name}"; then
        result="command \"${function_name}\" is not a declared function or a valid internal or external command "
        create_assert_failed_message "${test_command}" "${expected}" "${result}" "check_assert_command_defined"
        return 1
    fi
}

function get_returncode_as_string {
  # we need to do this because traps and err flags can be set and we disable them temporary
	# $1 : command
	local command result shell_state trap_state output
	command="${1}"

  # Save shell state, trap state and disable strict mode
  shell_state=$(set +o)
  trap_state=$(trap -p ERR)
  set +eEuo pipefail
  trap - ERR

  # check if the command even exists
  if ! check_assert_command_defined "${command}" "return code = 0"; then
      # Restore shell and trap state before returning
      eval "$shell_state"
      if [[ -n "$trap_state" ]]; then
          eval "$trap_state"
      fi
      echo "127"
      return 0
  fi

  # shellcheck disable=SC2034
  output=$(eval "${command}")
  result=$?               # Correctly capture numeric exit code

  # Restore shell and trap state
  eval "$shell_state"
  if [[ -n "$trap_state" ]]; then
      eval "$trap_state"
  fi

  echo "$result"
}

function get_result_as_string {
  # we need to do this because traps and err flags can be set and we disable them temporary
	# $1 : command
	local command result shell_state trap_state output
	command="${1}"

  # Save shell state, trap state and disable strict mode
  shell_state=$(set +o)
  trap_state=$(trap -p ERR)
  set +eEuo pipefail
  trap - ERR

  # check if the command even exists
  if ! check_assert_command_defined "${command}" "return code = 0"; then
      # Restore shell and trap state before returning
      eval "$shell_state"
      if [[ -n "$trap_state" ]]; then
          eval "$trap_state"
      fi
      echo ""
      return 0
  fi

  # shellcheck disable=SC2034
  output=$(eval "${command}")

  # Restore shell and trap state
  eval "$shell_state"
  if [[ -n "$trap_state" ]]; then
      eval "$trap_state"
  fi

  echo "$output"
}


function create_assert_failed_message {
	# $1 : test_command
	# $2 : expected
	# $3 : result
	# $4 : assert_function
  local test_command="${1}"
  local expected="${2}"
  local result="${3}"
  local assert_function="${4:-}"

	clr_reverse clr_red "*** ASSERT $assert_function FAILED ***"
	clr_reverse clr_cyan "File     : $(get_script_fullpath)"
	clr_cyan "Test     : ${test_command}"
	clr_green "Result   : ${result}"
	clr_red "Expected : ${expected}"
	echo ""
}

function assert_debug_message {
    # $1: should_debug: True/False
    # $2: debug_message
    local should_debug debug_message
    should_debug="${1}"
    debug_message="${2}"

    if [[ "${should_debug}" == "True" ]]; then
        clr_blue "\
        ** DEBUG *****************************************************************************************************${IFS}\
        File          : $(get_script_fullpath)${IFS}\
        Function      : ${FUNCNAME[ 1 ]}${IFS}\
        Caller        : ${FUNCNAME[ 2 ]}${IFS}\
        Debug Message : ${debug_message}${IFS}\
        **************************************************************************************************************"
    fi
}
