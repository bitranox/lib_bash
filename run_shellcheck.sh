#!/bin/bash

# --exclude=CODE1,CODE2..  Exclude types of warnings

function shell_check {

    # exclude Codes :
    # SC1091 not following external sources
    shellcheck --shell=bash --color=always \
        --exclude=SC1091 \
         ./*.sh


}

if [[ "${0}" == "${BASH_SOURCE[0]}" ]]; then    # if the script is not sourced
    shell_check
fi
