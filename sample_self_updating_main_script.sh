#!/bin/bash
## shellcheck disable=SC2164
## shellcheck disable=SC2155
## shellcheck disable=SC2034
source /usr/local/lib_bash/lib_bash.sh

function MAIN {
  echo "Hello World"
}

# update myself in a subshell
(
# shellcheck disable=SC2034
LIB_BASH_SELF_UPDATE_SELF=$(readlink -f "${BASH_SOURCE[0]}")
# shellcheck disable=SC2034
LIB_BASH_SELF_UPDATE_SELF_MAIN_FUNCTION="MAIN"
source /usr/local/lib_bash/self_update.sh
lib_bash_self_update "$@"
)

MAIN "$@"
