#!/bin/bash
# Shellcheck runner — Static analysis for test and top-level scripts
#
# Purpose:
# - Runs shellcheck over scripts in `.tests` and project root with a few excludes
#   to accommodate sourced files and dynamic paths in tests.
#
# Usage:
# - From repo root: `cd .tests && ./shellcheck.sh`
#
# Notes:
# - Excludes SC1090/SC1091 (can't follow dynamic sources) by default.

# --exclude=CODE1,CODE2..  Exclude types of warnings

function shell_check {

    # exclude Codes :
    # SC1091 not following external sources

    # check the tests
    shellcheck --shell=bash --color=always \
        --exclude=SC1091 \
        --exclude=SC1090 \
         ./*.sh

    # check the thing
    shellcheck --shell=bash --color=always \
        --exclude=SC1091 \
        --exclude=SC1090 \
         ../*.sh
}


shell_check
