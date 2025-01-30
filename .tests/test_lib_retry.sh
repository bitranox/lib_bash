#!/bin/bash
# test_lib_retry.sh

set -o errexit -o nounset -o pipefail

log_err() {
    echo "[log_err] $*" >&2
}

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source "${SCRIPT_DIR}/../lib_retry.sh"

TEST_COLOR_FAIL=$(tput setaf 1)
TEST_COLOR_PASS=$(tput setaf 2)
TEST_COLOR_RESET=$(tput sgr0)

test_log_custom() {
    echo "[CUSTOM_LOG] $*" >&2
}

test_runner() {
    local description=$1 expected_code=$2
    shift 2

    local -i actual_code=0
    echo "⊚ TEST: ${description}"

    set +e
    local output
    output=$(retry "$@" 2>&1)
    actual_code=$?
    set -e

    if ((actual_code != expected_code)); then
        printf "%sFAIL%s: Code %d (expected %d)\nOutput:\n%s\n\n" \
            "${TEST_COLOR_FAIL}" "${TEST_COLOR_RESET}" \
            "${actual_code}" "${expected_code}" "${output}"
        return 1
    else
        printf "%sPASS%s: Code %d\n\n" \
            "${TEST_COLOR_PASS}" "${TEST_COLOR_RESET}" \
            "${actual_code}"
        return 0
    fi
}

create_unreadable_file() {
    local temp_dir
    temp_dir=$(mktemp -d)
    chmod 700 "${temp_dir}"

    local test_file="${temp_dir}/test.txt"
    touch "${test_file}"
    chmod 000 "${test_file}"

    echo "${temp_dir}"  # Return temp_dir for cleanup
}

test_cleanup() {
    [[ -n "${temp_dir:-}" ]] && rm -rf "${temp_dir}"
    rm -f /tmp/retry_test  # Add this line
}

main() {
    local -i fail_count=0
    trap test_cleanup EXIT

    echo "🏁 Starting retry library test suite"

    # Basic tests
    test_runner "Successful command" 0 -n 2 -d 1 -- ls /tmp || ((fail_count++))
    # shellcheck disable=SC2016
    test_runner "Retry success" 0 -n 2 -d 1 -- bash -c '
        declare -i attempt
        if [[ -f /tmp/retry_test ]]; then
            attempt=$(< /tmp/retry_test)
        else
            attempt=0
        fi
        ((attempt++))
        echo $attempt > /tmp/retry_test
        ((attempt < 2)) && exit 1 || exit 0
    ' || ((fail_count++))

    test_runner "Exhausted retries" 1 -n 2 -d 1 -- bash -c 'exit 1' || ((fail_count++))
    test_runner "Invalid command" 127 -n 2 -d 1 -- invalid_command || ((fail_count++))
    test_runner "Permission denied" 126 -n 2 -d 1 -- bash -c 'exit 126' || ((fail_count++))
    test_runner "User interrupt" 130 -n 2 -d 1 -- bash -c 'exit 130' || ((fail_count++))
    test_runner "Custom logger" 1 -n 2 -d 1 -l test_log_custom -- bash -c 'exit 1' || ((fail_count++))
    test_runner "Invalid max attempts" 1 -n 0 -d 1 -- ls || ((fail_count++))
    test_runner "Invalid delay" 1 -n 2 -d 0 -- ls || ((fail_count++))
    test_runner "Missing command" 1 -n 2 -d 1 -- || ((fail_count++))

    # File permission test
    local temp_dir
    temp_dir=$(create_unreadable_file)
    test_runner "File access failure" 1 -n 1 -d 1 -- test -r "${temp_dir}/test.txt" || ((fail_count++))

    # Final results
    if ((fail_count > 0)); then
        echo -e "\n${TEST_COLOR_FAIL}❌ ${fail_count} tests failed${TEST_COLOR_RESET}"
        return 1
    else
        echo -e "\n${TEST_COLOR_PASS}✅ All tests passed${TEST_COLOR_RESET}"
        return 0
    fi
}

main "$@"
