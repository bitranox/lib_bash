#!/bin/bash

source run_all_tests.sh

function test_loop {
    while true; do
        run_all_tests
        sleep 1
    done
}

test_loop
