#!/bin/bash

source ../lib_helpers.sh

export SUDO_ASKPASS="$(command -v ssh-askpass)"

function test_loop {
    # local my_dir="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"  # this gives the full path, even for sourced scripts
    local files_to_test actual_file_to_test user

    while true; do

        files_to_test=($(ls ./test_*.sh))
        for actual_file_to_test in "${files_to_test[@]}"
        do
            "$(get_sudo)" "${actual_file_to_test}"
        done
        clr_green "test ok in 1 $(get_own_script_name "${BASH_SOURCE[0]}")"
        sleep 1
    done
}


test_loop
