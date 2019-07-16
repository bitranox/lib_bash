#!/bin/bash

# --exclude=CODE1,CODE2..  Exclude types of warnings

shellcheck --shell=bash --color=always \
    --exclude=SC1091 \
     ./*.sh



# exclude Codes :
# SC1091 not following external sources
