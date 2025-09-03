#!/bin/bash
# test_lib_helpers.sh — Tests for assorted helper functions in lib_bash.sh
#
# Purpose:
# - Exercise helper utilities such as package checks, string containment, env vars,
#   OS detection, and basic assertion functions.
#
# Usage:
# - From repo root: `cd .tests && ./test_lib_helpers.sh`
# - Or run `.tests/run_all_tests.sh` to execute all tests.

# Load your logging script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LIB_BASH_DISABLE_SELF_UPDATE=1
source "${SCRIPT_DIR}/../lib_bash.sh"


function run_tests {
  	# dummy_test 2>/dev/null || log_warn "no tests in ${BASH_SOURCE[0]}"
	  assert_pass "../lib_bash.sh is_package_installed apt"  # call verbatim -  we also get updates here
	  assert_pass "is_package_installed apt"
	  assert_fail "is_package_installed unknown-package-0815"
	  assert_pass "is_str1_in_str2 \"a\" \"aaa\""
	  assert_pass "is_str1_in_str2 \"a a\" \"aaa aaa\""
	  assert_fail "is_str1_in_str2 \"a b\" \"aaa aaa\""
	  assert_fail "is_str1_in_str2 \"z\" \"aaa\""
	  assert_pass "is_str1_in_str2 \"\" \"aaa\""
	  assert_fail "is_str1_in_str2 \"a\" \"\""
	  assert_pass "is_str1_in_str2 \"\" \"\""
	  assert_pass "is_str1_in_str2 \"complex-\*\\[\\!\\]\" \"this is a complex-\*\\[\\!\\] string\""
    assert_pass "get_linux_release_number"
    assert_pass "get_linux_release_number_major"
    assert_fail "is_script_sourced ${0} ${BASH_SOURCE[0]}"
    assert_fail "is_hetzner_virtual_server"
    assert_equal "echo \"printenv USER: $(printenv USER)\" : $USER" "printenv USER: $USER : $USER"  # check if env user is the same as the Variable $USER
    log_ok "Tests finished"
}

run_tests
