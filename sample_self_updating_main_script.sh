#!/bin/bash
## shellcheck disable=SC2164
## shellcheck disable=SC2155
## shellcheck disable=SC2034
echo "source lib_bash.sh from sample_self_updaiting_main_script.sh"
source /usr/local/lib_bash/lib_bash.sh

function SAMPLE_MAIN {
  echo "Hello World"
}

# update myself in a subshell - only once per session
if [[ ! -v LIB_BASH_DO_NOT_UPDATE ]] ; then
    declare -r LIB_BASH_DO_NOT_UPDATE="true" &>/dev/null
    # shellcheck disable=SC2034
    LIB_BASH_SELF_UPDATE_SELF=$(readlink -f "${BASH_SOURCE[0]}")
    # shellcheck disable=SC2034
    LIB_BASH_SELF_UPDATE_SELF_MAIN_FUNCTION="SAMPLE_MAIN"
    source /usr/local/lib_bash/self_update.sh
    lib_bash_self_update "$@"
fi

echo "CALLING SAMPLE_MAIN" "${0}" "${@}"
SAMPLE_MAIN "$@"
