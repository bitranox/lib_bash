#!/bin/bash

sudo_askpass="$(command -v ssh-askpass)"
export SUDO_ASKPASS="${sudo_askpass}"
export NO_AT_BRIDGE=1  # get rid of (ssh-askpass:25930): dbind-WARNING **: 18:46:12.019: Couldn't register with accessibility bus: Did not receive a reply.

function include_dependencies {
    local my_dir
    # shellcheck disable=SC2164
    my_dir="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"  # this gives the full path, even for sourced scripts
    # shellcheck disable=SC1090
    source "${my_dir}/lib_helpers.sh"
}

include_dependencies

function get_octal_permission {
    # $1: file or directory
    # returns 755 or whatever code
    local file="$1"
    stat -c "%a" "$file"
}

function is_permission {
    # $1: file or directory
    # $2: permission with 3 digits
    local file="$1"
    local permission="$2"
    if [[ "$(get_octal_permission "$file")" -eq "$permission" ]]; then
        exit 0
    else
        exit 1
    fi
}


function set_lib_bash_permissions {
    local user
    user="$(printenv USER)"
    $(command -v sudo 2>/dev/null) chmod -R 0755 /usr/local/lib_bash
    $(command -v sudo 2>/dev/null) chmod -R +x /usr/local/lib_bash/*.sh
    $(command -v sudo 2>/dev/null) chown -R root /usr/local/lib_bash || "$(command -v sudo 2>/dev/null)" chown -R "${user}" /usr/local/lib_bash || echo "giving up set owner" # there is no user root on travis
    $(command -v sudo 2>/dev/null) chgrp -R root /usr/local/lib_bash || "$(command -v sudo 2>/dev/null)" chgrp -R "${user}" /usr/local/lib_bash || echo "giving up set group" # there is no user root on travis
}


# if it is not installed on the right place, we install it on /usr/local/bin
function is_lib_bash_installed {
        if [[ -f "/usr/local/lib_bash/install_or_update.sh" ]]; then
            return 0
        else
            return 1
        fi
}


# this checks the install directory version - but it might be installed for testing somewhere else - that will not be updated.
function is_lib_bash_up_to_date {
    local git_remote_hash git_local_hash
    git_remote_hash=$(git --no-pager ls-remote --quiet https://github.com/bitranox/lib_bash.git | grep HEAD | awk '{print $1;}' )
    git_local_hash=$(cat /usr/local/lib_bash/.git/refs/heads/master)
    if [[ "${git_remote_hash}" == "${git_local_hash}" ]]; then
        return 0
    else
        return 1
    fi
}


function install_lib_bash {
    echo "installing lib_bash"
    $(command -v sudo 2>/dev/null) rm -fR /usr/local/lib_bash
    $(command -v sudo 2>/dev/null) git clone https://github.com/bitranox/lib_bash.git /usr/local/lib_bash > /dev/null 2>&1
    set_lib_bash_permissions
}


function update_lib_bash {

    (
        clr_green "updating lib_bash"
        # create a subshell to preserve current directory
        cd /usr/local/lib_bash || fail "error in update_lib_bash"
        $(command -v sudo 2>/dev/null) git fetch --all  > /dev/null 2>&1
        $(command -v sudo 2>/dev/null) git reset --hard origin/master  > /dev/null 2>&1
        set_lib_bash_permissions
    )
}



if [[ "${0}" == "${BASH_SOURCE[0]}" ]]; then    # if the script is not sourced

    if ! is_lib_bash_installed; then install_lib_bash ; fi  # if it is just downloaded and not installed at the right place

    if ! is_lib_bash_up_to_date; then
        update_lib_bash
        source "$(readlink -f "${BASH_SOURCE[0]}")"      # source ourself
        exit 0                                           # exit the old instance
    fi
fi
