#!/bin/bash

export bitranox_debug="True"

function source_lib_color {
    # this is needed, otherwise "${@}" will be passed to lib_color
    source /usr/local/lib_bash/lib_color.sh
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
    if [[ "${bitranox_debug}" == "True" ]]; then echo "lib_bash\install_or_update.sh@install_lib_bash: install lib_bash"; fi
    $(which sudo) rm -fR /usr/local/lib_bash
    $(which sudo) git clone https://github.com/bitranox/lib_bash.git /usr/local/lib_bash > /dev/null 2>&1
    set_lib_bash_permissions
    source_lib_color
}


function restart_calling_script {
    local caller_command=("$@")
    if [ ${#caller_command[@]} -eq 0 ]; then
        if [[ "${bitranox_debug}" == "True" ]]; then clr_blue "lib_bash\install_or_update.sh@restart_calling_script: no caller command - exit 0"; fi
        # no parameters passed
        exit 0
    else
        # parameters passed, running the new Version of the calling script
        if [[ "${bitranox_debug}" == "True" ]]; then clr_blue "lib_bash\install_or_update.sh@restart_calling_script: calling command : ${@}"; fi
        "${caller_command[@]}"
        if [[ "${bitranox_debug}" == "True" ]]; then clr_blue "lib_bash\install_or_update.sh@restart_calling_script: after calling command : ${@} - exiting with 100"; fi
        exit 100
    fi

}


function update_lib_bash {
    if [[ "${bitranox_debug}" == "True" ]]; then clr_blue "lib_bash\install_or_update.sh@update_lib_bash: updating lib_bash"; fi
    (
        # create a subshell to preserve current directory
        cd /usr/local/lib_bash
        $(which sudo) git fetch --all  > /dev/null 2>&1
        $(which sudo) git reset --hard origin/master  > /dev/null 2>&1
        set_lib_bash_permissions
    )
    if [[ "${bitranox_debug}" == "True" ]]; then clr_blue "lib_bash\install_or_update.sh@update_lib_bash: lib_bash update complete"; fi

}




if [[ $(is_lib_bash_installed) == "True" ]]; then
    source_lib_color
    if [[ $(is_lib_bash_up_to_date) == "False" ]]; then
        if [[ "${bitranox_debug}" == "True" ]]; then clr_blue "lib_bash\install_or_update.sh@main: lib_bash is not up to date"; fi
        update_lib_bash
        if [[ "${bitranox_debug}" == "True" ]]; then clr_blue "lib_bash\install_or_update.sh@main: call restart_calling_script ${@}"; fi
        restart_calling_script  "${@}"
        if [[ "${bitranox_debug}" == "True" ]]; then clr_blue "lib_bash\install_or_update.sh@main: call restart_calling_script ${@} returned ${?}"; fi
    else
        if [[ "${bitranox_debug}" == "True" ]]; then clr_blue "lib_bash\install_or_update.sh@main: lib_bash is up to date"; fi
    fi
else
    install_lib_bash
fi

