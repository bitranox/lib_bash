#!/bin/bash

source ../lib_helpers.sh


function run_tests {
	# dummy_test 2>/dev/null || clr_green "no tests in ${BASH_SOURCE[0]}"
    # banner_base clr_green "one line banner_base_test"
    # banner_base clr_green "two line ${IFS}banner_base_test"
    assert_pass "../lib_color.sh clr_cyan test-verbatim"  # call verbatim - we also get updates here
    assert_pass "clr_cyan test-sourced"



}

run_tests
