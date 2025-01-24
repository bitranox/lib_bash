##!/bin/bash
## shellcheck disable=SC2164
## shellcheck disable=SC2155
## shellcheck disable=SC2034

function MAIN {
  echo "Hello World"
}

# update myself in a subshell
(
LIB_BASH_SELF_UPDATE_SELF=$(readlink -f "${BASH_SOURCE[0]}")
source /usr/local/lib_bash/self_update.sh
lib_bash_self_update "$@"
)

MAIN "$@"
