#!/bin/bash
# shellcheck disable=SC2155

function assert_equal {
	# $1 : test_command
	# $2 : expected
	local test_command expected result

	test_command="${1}"
	expected="${2}"
    check_assert_command_defined "${test_command}" "${expected}" || return 0
    result=$(eval "${1}")

	if [[ "${result}" != "${expected}" ]]; then
	    create_assert_failed_message "${test_command}" "\"${expected}\"" "\"${result}\""
    fi
}

function assert_contains {
	# $1 : test_command
	# $2 : expected
	local test_command expected result
	test_command="${1}"
	expected="${2}"
    check_assert_command_defined "${test_command}" "*${expected}*" || return 0
    result=$(eval "${1}")

	if [[ "${result}" != *"${expected}"* ]]; then
	    create_assert_failed_message "${test_command}" "\"*${expected}*\"" "\"${result}\""
	    fi
}

function assert_return_code {
	# $1 : test_command
	# $2 : expected
	local test_command expected result
	test_command="${1}"
	expected="${2}"
    check_assert_command_defined "${test_command}" "return code = ${expected}" || return 0
    eval "${1}"
    result="${?}"
	if [[ "${result}" -ne "${expected}" ]]; then
	    create_assert_failed_message "${test_command}" "return code = ${expected}" "return code = ${result}"
    fi
}

function assert_pass {
	# $1 : test_command
	local test_command result
	test_command="${1}"
  check_assert_command_defined "${test_command}" "return code = 0" || return 0
  result=$(eval_function "${1}")
  if [[ "${result}" != "0" ]]; then
	    create_assert_failed_message "${test_command}" "return code = 0" "return code = ${result}" "assert_pass"
    fi
}

function assert_fail {
	# $1 : test_command
	local test_command result
	local shell_state

	test_command="${1}"
  check_assert_command_defined "${test_command}" "return code > 0" || return 0
  result=$(eval_function "${1}")
  if [[ "${result}" == "0" ]]; then
      create_assert_failed_message "${test_command}" "return code > 0" "return code = ${result}" "assert_fail"
  fi
}

eval_function() {
    # we need this to disable shell states and trap states, otherwise eval can just exit
    # we need to pass back "OK" or "FALSE" because script would just exit on returncode 1 if a trap is set
    local command result
    local shell_state trap_state

    command="${1}"

    # Save shell state, trap state and disable strict mode
    shell_state=$(set +o)
    trap_state=$(trap -p ERR)
    set +eEuo pipefail
    trap - ERR

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

function create_assert_failed_message {

	# $1 : test_command
	# $2 : expected
	# $3 : expected
	# $4 : assert_function
  local test_command="${1}"
  local expected="${2}"
  local result="${3}"
  local assert_function="${4}:-"

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
