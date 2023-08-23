#!/bin/bash

function default_actions {
sudo_askpass="$(command -v ssh-askpass)"
export SUDO_ASKPASS="${sudo_askpass}"
export NO_AT_BRIDGE=1  # get rid of ssh-askpass:25930 dbind-WARNING
}
default_actions

# call the update script if not sourced and not already done in that session
if [[ "${0}" == "${BASH_SOURCE[0]}" ]] && [[ -d "${BASH_SOURCE%/*}" ]] && [[ "${lib_bash_is_up_to_date_in_this_session}" != "True" ]]; then
    /usr/local/lib_bash/install_or_update.sh
    lib_bash_is_up_to_date_in_this_session="True"
fi


function include_dependencies {
    local my_dir
    # shellcheck disable=SC2164
    my_dir="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"  # this gives the full path, even for sourced scripts
    source "${my_dir}/lib_helpers.sh"
}

include_dependencies


function lxc_exec {
    # parameter: $1 = container_name
    # parameter: $2 = shell_command
    local container_name=$1
    local shell_command=$2
    lxc exec "${container_name}" -- sh -c "${shell_command}"
}


function lxc_update {
    # parameter: $1 = container_name
    local container_name=$1
    retry lxc_exec "${container_name}" "sudo apt-get update"
    retry lxc_exec "${container_name}" "sudo apt-get upgrade -y"
    retry lxc_exec "${container_name}" "sudo apt-get dist-upgrade -y"
    retry lxc_exec "${container_name}" "sudo apt-get autoclean -y"
    retry lxc_exec "${container_name}" "sudo apt-get autoremove -y"
}


function lxc_wait_until_machine_stopped {
    # parameter: $1 = container_name
    local container_name=$1
    clr_green "Container ${container_name}: stopping"
    while true; do
        if [[ $(lxc list -cns | grep "${container_name}" | grep -c STOPPED) == "1" ]]; then
            break
        else
            sleep 1
            clr_green "Container ${container_name}: wait for stopping"
        fi
    done
    clr_green "Container ${container_name}: stopped"
}


function lxc_wait_until_machine_running {
    # parameter: $1 = container_name
    local container_name=$1
    clr_green "Container ${container_name}: starting"
    while true; do
        if [[ $(lxc list -cns | grep "${container_name}" | grep -c RUNNING) == "1" ]]; then
            break
        else
            sleep 1
            clr_green "Container ${container_name}: wait for startup"
        fi
    done
    clr_green "Container ${container_name}: started"
}


# This directive only applies to this function
# shellcheck disable=SC2015
function lxc_wait_until_internet_connected {
    # parameter: $1 = container_name
    local container_name="${1}"
    clr_green "Container ${container_name}: wait for internet connection"
    while true; do
        lxc_exec "${container_name}" "sudo wget -q --spider http://google.com" \
        && break \
        || (sleep 1; clr_green "Container ${container_name}: wait for internet connection")
    done
    clr_green "Container ${container_name}: internet connected"
}


function lxc_startup {
    # parameter: $1 = container_name
    local container_name=$1
    banner "Container ${container_name}: Startup"
    lxc start "${container_name}"
    lxc_wait_until_machine_running "${container_name}"
}


function lxc_shutdown {
    # parameter: $1 = container_name
    local container_name=$1
    banner "Container ${container_name}: Shutdown"
    lxc_exec "${container_name}" "sudo shutdown now"
    lxc_wait_until_machine_stopped "${container_name}"
}


function lxc_reboot {
    # parameter: $1 = container_name
    local container_name=$1
    banner "Container ${container_name}: Rebooting"
    lxc_shutdown "${container_name}"
    sleep 1
    lxc_startup "${container_name}"
}


function lxc_replace_or_add_lines_containing_string_in_file {
    # $1 = container_name
    # $2 = File
    # $3 = search string
    # $4 = new line to replace
    local container_name path_file search_string new_line number_of_lines_found

    container_name="${1}"
    path_file="${2}"
    search_string="${3}"
    new_line="${4}"
    number_of_lines_found=$(lxc exec "${container_name}" -- sh -c "grep -c ${search_string} ${path_file}")
    if [[ $((number_of_lines_found)) -gt 0 ]]; then
        # replace lines if there
        lxc exec "${container_name}" -- sh -c "sudo sed -i \"/${search_string}/c\\\\${new_line}\" ${path_file}"
    else
        # add line if not there
        # shellcheck disable=SC2086
        lxc exec "${container_name}" -- sh -c "sudo sh -c \"echo \\"${new_line}\\" >> ${path_file}\""
    fi
}

function  lxc_path_exist {
    # $1 = container_name
    # $2 = Path to File or Directory
    local container_name="${1}"
    local path_file="${2}"
    # shellcheck disable=SC2086
    # if lxc_exec "${container_name}" "test -e \\"${path_file}\\""; then
    if lxc_exec "${container_name}" "test -e ${path_file}"; then
      return 0
    else
      return 1
    fi
}

## make it possible to call functions without source include
call_function_from_commandline "${0}" "${@}"

