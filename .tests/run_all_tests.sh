#!/bin/bash
# run_all_tests.sh — Discover and run all test_*.sh, then shellcheck
#
# Purpose:
# - Sources the project library via lib_bash.sh, executes every test_*.sh in this
#   directory, then runs shellcheck over tests and top-level scripts.
#
# Usage:
# - From repo root: `cd .tests && ./run_all_tests.sh`
# - Or source and call `run_all_tests`.
#
# Notes:
# - Expects test files to be executable and located in `.tests` with prefix `test_`.
# - Requires shellcheck for static analysis step.

# Load your logging script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LIB_BASH_DISABLE_SELF_UPDATE=1
# route apt/dpkg tools to mocks to avoid real package ops in tests
export APT_GET_BIN="${SCRIPT_DIR}/mocks/apt-get"
export DPKG_BIN="${SCRIPT_DIR}/mocks/dpkg"
export APT_MARK_BIN="${SCRIPT_DIR}/mocks/apt-mark"
export SYSTEMD_TMPFILES_BIN="${SCRIPT_DIR}/mocks/systemd-tmpfiles"
export LIB_BASH_TEST_MOCKS_DIR="${SCRIPT_DIR}/mocks"
hash -r
source "${SCRIPT_DIR}/../lib_bash.sh"

sudo_askpass="$(command -v ssh-askpass)"
export SUDO_ASKPASS="${sudo_askpass}"
export NO_AT_BRIDGE=1  # get rid of (ssh-askpass:25930): dbind-WARNING **: 18:46:12.019: Couldn't register with accessibility bus: Did not receive a reply.

function run_all_tests {
    # shellcheck disable=SC2164
    # local my_dir="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"  # this gives the full path, even for sourced scripts
    local files_to_test actual_file_to_test

    local -i fail_count=0
    local TEST_TIMEOUT=${TEST_TIMEOUT:-60}
    mapfile -t files_to_test < <(ls ./test_*.sh)
    for actual_file_to_test in "${files_to_test[@]}"; do
        echo "Running ${actual_file_to_test} (timeout ${TEST_TIMEOUT}s)" >&2
        if ! timeout "${TEST_TIMEOUT}" "${actual_file_to_test}"; then
            echo "Test timed out or failed: ${actual_file_to_test}" >&2
            ((fail_count++))
        fi
    done
    ./shellcheck.sh
    if (( fail_count == 0 )); then
        clr_green "test ok in ${BASH_SOURCE[0]}"
    else
        clr_red "${fail_count} test(s) failed or timed out"
        return 1
    fi
}

if [[ "${0}" == "${BASH_SOURCE[0]}" ]]; then    # if the script is not sourced
    run_all_tests
fi
