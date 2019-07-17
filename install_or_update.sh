#!/bin/bash

export bitranox_debug_global="${bitranox_debug_global}"  # set to True for global Debug
export debug_lib_bash="False"


function get_my_dir {
    local mydir
    mydir="${BASH_SOURCE%/*}"
    if [[ ! -d "${mydir}" ]]; then mydir="${PWD}"; fi
    echo "${mydir}"
}


function include_dependencies {
    local mydir
    mydir="$(get_my_dir)"
    source "${mydir}/lib_helpers.sh"
}

include_dependencies


function set_lib_bash_permissions {
    local user
    user="$(printenv USER)"
    $(command -v sudo 2>/dev/null) chmod -R 0755 "$(get_my_dir)"
    $(command -v sudo 2>/dev/null) chmod -R +x "$(get_my_dir)/*.sh"
    $(command -v sudo 2>/dev/null) chown -R root "$(get_my_dir)" || $(command -v sudo 2>/dev/null) chown -R "${user}" "$(get_my_dir)"  || echo "giving up set owner" # there is no user root on travis
    $(command -v sudo 2>/dev/null) chgrp -R root "$(get_my_dir)" || $(command -v sudo 2>/dev/null) chgrp -R "${user}" "$(get_my_dir)"  || echo "giving up set group" # there is no user root on travis
}

function is_lib_bash_up_to_date {
    local git_remote_hash=""
    local git_local_hash=""
    git_remote_hash=$(git --no-pager ls-remote --quiet https://github.com/bitranox/lib_bash.git | grep HEAD | awk '{print $1;}' )
    git_local_hash=$( $(command -v sudo 2>/dev/null) cat /usr/local/lib_bash/.git/refs/heads/master)
    if [[ "${git_remote_hash}" == "${git_local_hash}" ]]; then
        echo "True"
    else
        echo "False"
    fi
}

function install_lib_bash {
    echo "installing lib_bash"
    $(command -v sudo 2>/dev/null) rm -fR /usr/local/lib_bash
    $(command -v sudo 2>/dev/null) git clone https://github.com/bitranox/lib_bash.git /usr/local/lib_bash > /dev/null 2>&1
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
        debug "${debug_lib_bash}" "calling command : $*"
        "${caller_command[@]}"
        debug "${debug_lib_bash}" "after calling command $* : exiting with 100"
        exit 100
    fi
}


function update_lib_bash {
    clr_green "updating lib_bash"
    (
        # create a subshell to preserve current directory
        cd /usr/local/lib_bash || fail "error in update_lib_bash"
        $(command -v sudo 2>/dev/null) git fetch --all  > /dev/null 2>&1
        $(command -v sudo 2>/dev/null) git reset --hard origin/master  > /dev/null 2>&1
        set_lib_bash_permissions
    )
    debug "${debug_lib_bash}" "lib_bash update complete"
}



if [[ "${0}" == "${BASH_SOURCE[0]}" ]]; then    # if the script is not sourced
    set_lib_bash_permissions
    if [[ $(is_lib_bash_up_to_date) == "False" ]]; then
        debug "${debug_lib_bash}" "lib_bash is not up to date"
        update_lib_bash
        source "${0}"   # source ourself
        exit 0          # exit the old instance
    else
        debug "${debug_lib_bash}" "lib_bash is up to date"
    fi
fi
