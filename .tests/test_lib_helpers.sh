#!/bin/bash

source ../lib_helpers.sh


function test {
	# dummy_test 2>/dev/null || clr_green "no tests in ${BASH_SOURCE[0]}"
    # banner_base clr_green "one line banner_base_test"
    # banner_base clr_green "two line ${IFS}banner_base_test"
	assert_equal "is_str1_in_str2 \"a\" \"aaa\"" "True"
	assert_equal "is_str1_in_str2 \"a a\" \"aaa aaa\"" "True"
	assert_equal "is_str1_in_str2 \"a b\" \"aaa aaa\"" "False"

    assert_equal "get_sudo" "/usr/bin/sudo"
    assert_equal "get_linux_release_number" "19.04"
    assert_equal "get_linux_release_number_major" "19"
	assert_equal "get_is_package_installed apt" "True"
    # assert_equal "get_prepend_auto_configuration_message_to_line test" "auto configured by bitranox configmagick scripts at 2019-07-17 12:53:05\\ntest"
    assert_equal "is_script_sourced_new" ""

}

test
