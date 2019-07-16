#!/bin/bash

function test_loop {
    local my_dir="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"  # this gives the full path, even for sourced scripts
    local files_to_test=( )
    local actual_file_to_test=""

    while [[ 1=1 ]]; do

        ./install_or_update.sh

        files_to_test=( $(sudo ls "${my_dir}"/*.sh ) )
        for actual_file_to_test in "${files_to_test[@]}"
        do
            source "${actual_file_to_test}"
            tests
        done
    done
}


test_loop
