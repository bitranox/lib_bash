#!/bin/bash

source ../lib_bash.sh


function run_tests {
	# dummy_test 2>/dev/null || clr_green "no tests in ${BASH_SOURCE[0]}"
    # banner_base clr_green "one line banner_base_test"
    # banner_base clr_green "two line ${IFS}banner_base_test"
    assert_pass "../lib_color.sh clr_blue test-verbatim"  # call verbatim
    assert_pass "clr_cyan test-sourced"
}

run_tests
