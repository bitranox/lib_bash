#!/bin/bash

# --exclude=CODE1,CODE2..  Exclude types of warnings

function shell_check {

    # exclude Codes :
    # SC1091 not following external sources
    shellcheck --shell=bash --color=always \
        --exclude=SC1091 \
        --exclude=SC1090 \
         ../*.sh


}

shell_check
