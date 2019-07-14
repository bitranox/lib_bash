#!/bin/bash

# function include_dependencies {
#     my_dir="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"  # this gives the full path, even for sourced scripts
#     source "${my_dir}/lib_color.sh"
#     source "${my_dir}/lib_helpers.sh"
#
# }
#
# include_dependencies  # we need to do that via a function to have local scope of my_dir

function set_lib_bash_permissions {
    $(which sudo) chmod -R 0755 /usr/local/lib_bash
    $(which sudo) chmod -R +x /usr/local/lib_bash/*.sh
    $(which sudo) chown -R root /usr/local/lib_bash || $(which sudo) chown -R ${USER} /usr/local/lib_bash  || echo "giving up set owner" # there is no user root on travis
    $(which sudo) chgrp -R root /usr/local/lib_bash || $(which sudo) chgrp -R ${USER} /usr/local/lib_bash  || echo "giving up set group" # there is no user root on travis
}

function is_lib_bash_installed {
        if [[ -f "/usr/local/lib_bash/install_or_update.sh" ]]; then
            echo "True"
        else
            echo "False"
        fi
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
    echo "installing lib_bash"
    $(which sudo) rm -fR /usr/local/lib_bash
    $(which sudo) git clone https://github.com/bitranox/lib_bash.git /usr/local/lib_bash > /dev/null 2>&1
    set_lib_bash_permissions
}

function update_lib_bash {
    if [[ $(is_lib_bash_up_to_date) == "False" ]]; then
        clr_green "lib_bash needs to update"
        (
            # create a subshell to preserve current directory
            cd /usr/local/lib_bash
            $(which sudo) git fetch --all  > /dev/null 2>&1
            $(which sudo) git reset --hard origin/master  > /dev/null 2>&1
            set_lib_bash_permissions
        )
        clr_green "lib_bash update complete"
    else
        clr_green "lib_bash is up to date"
    fi

}

function restart_calling_script {
    local caller_command=("$@")
    if [ ${#caller_command[@]} -eq 0 ]; then
        echo "no caller command - exit 0"
        # no parameters passed
        exit 0
    else
        # parameters passed, running the new Version of the calling script
        echo "caller command : $@ - exit 100"
        "${caller_command[@]}"
        # exit this old instance with error code 100
        exit 100
    fi

}

function source_lib_color {
    # this is needed, otherwise "${@}" will be passed to lib_color
    source /usr/local/lib_bash/lib_color.sh
}


if [[ $(is_lib_bash_installed) == "True" ]]; then
    source_lib_color
    update_lib_bash
    restart_calling_script  "${@}"  # needs caller name and parameters
else
    install_lib_bash
fi
