#!/bin/bash

# export bitranox_debug_global=False
# export debug_lib_bash="False"


function include_dependencies {
    source /usr/local/lib_bash/lib_color.sh
    source /usr/local/lib_bash/lib_helpers.sh
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


function lxc_wait_until_internet_connected {
    # parameter: $1 = container_name
    local container_name=$1
    clr_green "Container ${container_name}: wait for internet connection"
    while true; do
        lxc_exec "${container_name}" "sudo wget -q --spider http://google.com"
        if [[ $? -eq 0 ]]; then
            break
        else
            sleep 1
            clr_green "Container ${container_name}: wait for internet connection"
        fi
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
    local container_name=$1
    local path_file=$2
    local search_string=$3
    local new_line=$4
    local number_of_lines_found=$(lxc exec $container_name -- sh -c "cat $path_file | grep -c $search_string")
    if [[ $((number_of_lines_found)) > 0 ]]; then
        # replace lines if there
        lxc exec $container_name -- sh -c "sudo sed -i \"/$search_string/c\\\\$new_line\" $path_file"
    else
        # add line if not there
        lxc exec $container_name -- sh -c "sudo sh -c \"echo \\"$new_line\\" >> $path_file\""
    fi
}


function check_if_bash_function_is_declared {
    # $1 : function name
    local function_name="${1}"
    declare -F ${function_name} &>/dev/null && echo "True" || echo "False"
}


function call_function_from_commandline {
    # $1 : library_name ("${0}")
    # $2 : function_name ("${1}")
    # $3 : call_args ("${@}")
    local library_name="${1}"
    local function_name="${2}"
    local call_args_array=("${@}")

    if [[ ! -z ${function_name} ]]; then
        if [[ $(check_if_bash_function_is_declared "${function_name}") == "True" ]]; then
            ${call_args_array[@]:1}
        else
            fail "${function_name} is not a known function name of ${library_name}"
        fi
    fi
}


function tests {
	clr_green "no tests in $(get_own_script_name)"
}


## make it possible to call functions without source include
call_function_from_commandline "${0}" "${@}"
