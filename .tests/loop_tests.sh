#!/bin/bash
# loop_tests.sh — Continuously run test suite in a loop
#
# Purpose:
# - Calls run_all_tests repeatedly with a small delay, handy during development.
#
# Usage:
# - From repo root: `cd .tests && ./loop_tests.sh`
#
# Notes:
# - Press Ctrl+C to stop the loop.

source run_all_tests.sh

function test_loop {
    while true; do
        run_all_tests
        sleep 1
    done
}

test_loop
