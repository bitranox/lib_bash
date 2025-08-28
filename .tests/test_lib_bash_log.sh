#!/usr/bin/env bash
# test_lib_bash_log.sh — Tests for the logging library
#
# Purpose:
# - Validate core log functions, debug behavior, directory creation, and
#   command logging helpers `logc` and `logc_err` including exit codes.
#
# Usage:
# - From repo root: `cd .tests && ./test_lib_bash_log.sh`
# - Or run `.tests/run_all_tests.sh` to execute all tests.
#
# Notes:
# - Provides minimal mocks for functions expected by lib_bash.
# - Writes logs under `/tmp/lib_bash_test_logs` for inspection during tests.
# set -u  # leave -e off so we can capture failures and continue

# Optional: debug
# set -x

# Load your logging script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib_bash.sh"

# ------------------------------------------------------------------------------
# Mocks for required external functions used by lib_bash
# ------------------------------------------------------------------------------
get_script_stem() { echo "testscript"; }
register_temppath() { :; }
is_root() { return 1; }

# Dummy color functions (no-op)
clr_green() { echo "$1"; }
clr_bold() { echo "$1"; }
clr_yellow() { echo "$1"; }
clr_cyan() { echo "$1"; }
clr_magentab() { echo "$1"; }

echo "🔧 Starting logging function tests..."

# ------------------------------------------------------------------------------
# Run test helper
# Args: description expected_status command args...
# ------------------------------------------------------------------------------
run_test() {
    local desc="$1"
    local expected_status="$2"
    shift 2

    echo "▶️ Running test: $desc"
    if "$@"; then
        actual_status=0
    else
        actual_status=$?
    fi

    if [[ "$actual_status" -eq "$expected_status" ]]; then
        echo "✅ Passed: $desc"
    else
        echo "❌ Failed: $desc (expected $expected_status, got $actual_status)"
    fi
}

# ------------------------------------------------------------------------------
# Setup log paths
# ------------------------------------------------------------------------------
mkdir -p /tmp/lib_bash_test_logs
LIB_BASH_LOGFILE="/tmp/lib_bash_test_logs/test.log"
# shellcheck disable=SC2034
LIB_BASH_LOGFILE_TMP="/tmp/lib_bash_test_logs/test_tmp.log"
LIB_BASH_LOGFILE_ERR="/tmp/lib_bash_test_logs/test_err.log"
# shellcheck disable=SC2034
LIB_BASH_LOGFILE_ERR_TMP="/tmp/lib_bash_test_logs/test_err_tmp.log"

# Reset log state
_set_default_logfiles RESET
_set_default_logfile_colors RESET
_set_default_debugmode RESET

# ------------------------------------------------------------------------------
# Core log function tests
# ------------------------------------------------------------------------------
run_test "log message" 0 log "Test log line"
run_test "log bold message" 0 log "Bold test" "bold"
run_test "warn message" 0 log_warn "Warning test"
run_test "error message" 0 log_err "Error test"

# ------------------------------------------------------------------------------
# Debug mode tests
# ------------------------------------------------------------------------------
run_test "debug (OFF - should skip)" 0 log_debug "This won't show"
LIB_BASH_DEBUG_MODE="ON"
run_test "debug (ON - should log)" 0 log_debug "Debug output"
# shellcheck disable=SC2034
LIB_BASH_DEBUG_MODE="OFF"

# ------------------------------------------------------------------------------
# Edge case tests (expect failure due to empty input)
# ------------------------------------------------------------------------------
run_test "log empty" 1 log ""
run_test "warn empty" 1 log_warn ""
run_test "error empty" 1 log_err ""
run_test "debug empty" 1 log_debug ""

# ------------------------------------------------------------------------------
# Directory creation (success + failure)
# ------------------------------------------------------------------------------
run_test "create missing directory" 0 _create_log_dir "/tmp/log_create_check/foo.log"

readonly_dir="/tmp/readonly_test"
mkdir -p "$readonly_dir"
chmod -w "$readonly_dir"
trap 'chmod +w "$readonly_dir"; rm -rf "$readonly_dir"' EXIT

(
    set +e
    echo "🔧 Testing _create_log_dir failure path (readonly dir)"
    _create_log_dir "$readonly_dir/fail.log"
)

# ------------------------------------------------------------------------------
# Command logging: logc and logc_err
# ------------------------------------------------------------------------------
run_test "logc with success" 0 logc echo "logc succeeded"
run_test "logc with failure" 1 logc false

run_test "logc_err output" 0 logc_err echo "always logs as error"
run_test "logc_err failure" 1 logc_err false

# ------------------------------------------------------------------------------
# Optional: Check log files contain expected entries
# ------------------------------------------------------------------------------
grep "Test log line" "$LIB_BASH_LOGFILE" > /dev/null \
    && echo "✅ Log message written to log file"

grep "Error test" "$LIB_BASH_LOGFILE_ERR" > /dev/null \
    && echo "✅ Error message written to error log file"

echo "🧪 Logging test suite complete."
