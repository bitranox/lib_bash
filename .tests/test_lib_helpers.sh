#!/bin/bash

# Load your logging script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib_bash.sh"


function run_tests {
  	# dummy_test 2>/dev/null || log_warn "no tests in ${BASH_SOURCE[0]}"
	  assert_pass "../lib_bash.sh is_package_installed apt"  # call verbatim -  we also get updates here
	  assert_fail "../lib_bash.sh is_package_installed unknown-package-0815"  # call verbatim
	  assert_pass "is_str1_in_str2 \"a\" \"aaa\""
	  assert_pass "is_str1_in_str2 \"a a\" \"aaa aaa\""
	  assert_fail "is_str1_in_str2 \"a b\" \"aaa aaa\""
    assert_pass "get_linux_release_number"
    assert_pass "get_linux_release_number_major"
	  assert_pass "is_package_installed apt"
	  assert_fail "is_package_installed unknown-package-0815"
    assert_fail "is_script_sourced"
    assert_fail "is_hetzner_virtual_server"
    assert_equal "echo \"printenv USER: $(printenv USER)\" : $USER" "printenv USER: $USER : $USER"  # check if env user is the same as the Variable $USER
}

run_tests
