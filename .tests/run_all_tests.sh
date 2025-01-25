#!/bin/bash

source ../lib_bash.sh

sudo_askpass="$(command -v ssh-askpass)"
export SUDO_ASKPASS="${sudo_askpass}"
export NO_AT_BRIDGE=1  # get rid of (ssh-askpass:25930): dbind-WARNING **: 18:46:12.019: Couldn't register with accessibility bus: Did not receive a reply.

function run_all_tests {
    # shellcheck disable=SC2164
    # local my_dir="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"  # this gives the full path, even for sourced scripts
    local files_to_test actual_file_to_test

    mapfile -t files_to_test < <(ls ./test_*.sh)
    for actual_file_to_test in "${files_to_test[@]}"
    do
        "${actual_file_to_test}"
    done
    ./shellcheck.sh
    clr_green "test ok in ${BASH_SOURCE[0]}"
    sleep 1
}

if [[ "${0}" == "${BASH_SOURCE[0]}" ]]; then    # if the script is not sourced
    run_all_tests
fi
