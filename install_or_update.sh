#!/bin/bash

export bitranox_debug_lib_bash_install="True"
# export bitranox_debug_global="False"
# export bitranox_debug_lib_bash="False"


function source_lib_color {
    # this is needed, otherwise "${@}" will be passed to lib_color
    source /usr/local/lib_bash/lib_color.sh
}


function debug {
    # $1: debug_message
    local debug_message="${1}"
    local function_name=${FUNCNAME[ 1 ]}
    # local script_name=$( get_own_script_name )  # wenn lib_helpers is loaded, we get it automatically
    local script_name="/usr/local/lib_bash/install_or_update.sh"

    if [[ "${bitranox_debug_global}" == "True" ]]; then
        export bitranox_debug_lib_bash="True"
    fi
    if [[ "${bitranox_debug_lib_bash}" == "True" ]]; then
        export bitranox_debug_lib_bash_install="True"
    fi

#### sample Debug Message Template
if [[ "${bitranox_debug_lib_bash_install}" == "True" ]]; then clr_blue "\
# get_own_script_name


**************************************************************************************************************${IFS}\
File          : lib_bash/install_or_update.sh${IFS}\
Function      : ${function_name}${IFS}\
Debug Message : ${debug_message}${IFS}\
**************************************************************************************************************"; fi
}


function is_lib_bash_installed {
        if [[ -f "/usr/local/lib_bash/install_or_update.sh" ]]; then
            echo "True"
        else
            echo "False"
        fi
}

if [[ $(is_lib_bash_installed) == "True" ]]; then
    source_lib_color
fi

function set_lib_bash_permissions {
    $(which sudo) chmod -R 0755 /usr/local/lib_bash
    $(which sudo) chmod -R +x /usr/local/lib_bash/*.sh
    $(which sudo) chown -R root /usr/local/lib_bash || $(which sudo) chown -R ${USER} /usr/local/lib_bash  || echo "giving up set owner" # there is no user root on travis
    $(which sudo) chgrp -R root /usr/local/lib_bash || $(which sudo) chgrp -R ${USER} /usr/local/lib_bash  || echo "giving up set group" # there is no user root on travis
}

function is_lib_bash_up_to_date {
    local git_remote_hash=$(git --no-pager ls-remote --quiet https://github.com/bitranox/lib_bash.git | grep HEAD | awk '{print $1;}' )
    local git_local_hash=$( $(which sudo) cat /usr/local/lib_bash/.git/refs/heads/master)
    if [[ "${git_remote_hash}" == "${git_local_hash}" ]]; then
        echo "True"
    else
        echo "False"
    fi
}

function install_lib_bash {
    debug "installing lib_bash"
    $(which sudo) rm -fR /usr/local/lib_bash
    $(which sudo) git clone https://github.com/bitranox/lib_bash.git /usr/local/lib_bash > /dev/null 2>&1
    set_lib_bash_permissions
    source_lib_color
}


function restart_calling_script {
    local caller_command=("${@}")
    if [[ ${#caller_command[@]} -eq 0 ]]; then
        debug "no caller command - exit 0"
        # no parameters passed
        exit 0
    else
        # parameters passed, running the new Version of the calling script
        debug "calling command : ${@}"
        eval "${caller_command[@]}"
        debug "after calling command ${@} : exiting with 100"
        exit 100
    fi
}


function update_lib_bash {
    debug "updating lib_bash"
    (
        # create a subshell to preserve current directory
        cd /usr/local/lib_bash
        $(which sudo) git fetch --all  > /dev/null 2>&1
        $(which sudo) git reset --hard origin/master  > /dev/null 2>&1
        set_lib_bash_permissions
    )
    debug "lib_bash update complete"
}


function tests {
    clr_green "no tests in lib_bash/install_or_update"
}

if [[ $(is_lib_bash_installed) == "True" ]]; then
    source_lib_color
    if [[ $(is_lib_bash_up_to_date) == "False" ]]; then
        debug "lib_bash is not up to date"
        update_lib_bash
        debug "call restart_calling_script ${@}"
        restart_calling_script  "${@}"
        debug "call restart_calling_script ${@} returned with exit code ${?}"

    else
        debug "lib_bash is up to date"
    fi
else
    install_lib_bash
fi


## make it possible to call functions without source include
call_function_from_commandline "${0}" "${@}"
