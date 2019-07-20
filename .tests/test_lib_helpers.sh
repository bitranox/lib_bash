#!/bin/bash

source ../lib_helpers.sh


function run_tests {
	# dummy_test 2>/dev/null || clr_green "no tests in ${BASH_SOURCE[0]}"
    # banner_base clr_green "one line banner_base_test"
    # banner_base clr_green "two line ${IFS}banner_base_test"
	assert_pass "../lib_helpers.sh is_package_installed apt"  # call verbatim -  we also get updates here
	assert_fail "../lib_helpers.sh is_package_installed unknown-package-0815"  # call verbatim
	assert_pass "is_str1_in_str2 \"a\" \"aaa\""
	assert_pass "is_str1_in_str2 \"a a\" \"aaa aaa\""
	assert_fail "is_str1_in_str2 \"a b\" \"aaa aaa\""
    assert_pass "get_linux_release_number"
    assert_pass "get_linux_release_number_major"
	assert_pass "is_package_installed apt"
	assert_fail "is_package_installed unknown-package-0815"
    # assert_equal "get_prepend_auto_configuration_message_to_line test" "auto configured by bitranox configmagick scripts at 2019-07-17 12:53:05\\ntest"
    assert_fail "is_script_sourced"
    assert_fail "is_hetzner_virtual_server"
    assert_equal "get_home_directory_from_username ${USER}" "/home/${USER}"
    assert_equal "echo \"printenv USER: $(printenv USER)\" : $USER" "printenv USER: $USER : $USER"  # check if env user is the same as the Variable $USER
}

run_tests
