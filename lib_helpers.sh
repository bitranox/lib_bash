#!/bin/bash

# export bitranox_debug_global=False
export debug_lib_bash="False"

function include_dependencies {
    source /usr/local/lib_bash/lib_color.sh
}

include_dependencies


function get_own_script_name {
    # $1: script_name "${0}"
    # $2: bash_source "${BASH_SOURCE}"
    # returns the name of the current script, even if it is sourced
    local script_name="${1}"
    local bash_source="${2}"

    if [[ "${script_name}" != "${bash_source}" ]]; then
        echo "${bash_source}"
    else
        echo "${script_name}"
    fi
}

function is_script_sourced {
    # $1: script_name "${0}"
    # $2: bash_source "${BASH_SOURCE}"
    local script_name="${1}"
    local bash_source="${2}"
    if [[ "${script_name}" != "${bash_source}" ]]; then
        echo "True"
    else
        echo "False"
    fi
}

function debug {
    # $1: should_debug: True/False
    # $2: debug_message
    local should_debug="${1}"
    local debug_message="${2}"
    local script_name=$( get_own_script_name )

    if [[ "${bitranox_debug_global}" == "True" ]]; then
        should_debug="True"
    fi

    if [[ "${should_debug}" == "True" ]]; then clr_blue "\
    **************************************************************************************************************${IFS}\
    File          : ${script_name}{IFS}\
    Function      : ${FUNCNAME[ 1 ]}${IFS}\
    Caller        : ${FUNCNAME[ 2 ]}${IFS}\
    Debug Message : ${debug_message}${IFS}\
    **************************************************************************************************************"; fi
}


function assert_equal {
	# $1 : test
	# $2 : expected
	local test="${1}"
	local expected="${2}"
	local result=$(eval ${1})

	if [[ "${result}" != "${expected}" ]]; then
		clr_reverse clr_cyan  "File     : $0"
		clr_cyan "Test     : ${test}${IFS}Result   : ${result}${IFS}Expected : ${expected}"
		clr_red "***********************************************************************************************"
	fi
}


function get_log_file_name {
    # $1: script_name "${0}"
    # $2: bash_source "${BASH_SOURCE}"
    # usage : test=$(get_log_file_name "${0}" "${BASH_SOURCE}")
    # returns the name of the logfile : ${HOME}/log_usr_local_lib_<...>_001_000_<...>.log
    local script_name="${1}"
    local bash_source="${2}"
    local own_script_name_full=$(get_own_script_name "${script_name}" "${bash_source}")
    local own_script_name_wo_extension=${own_script_name_full%.*}
    local own_script_name_wo_extension_dashed=$(echo "${own_script_name_wo_extension}" | tr '/' '_' )
    local log_file_name="${HOME}"/log"${own_script_name_wo_extension_dashed}".log
    echo "${log_file_name}"
}


function get_user_from_fileobject {
    # $1: File or Directory
    # returns user
    local path_file="${1}"
    local user=$(stat -c "%U$" "${path_file}")
    echo "${user}"
}

function get_group_from_fileobject {
    # $1: File or Directory
    # returns group
    local path_file="${1}"
    local group=$(stat -c "%G" "${path_file}")
    echo "${group}"
}


function add_user_as_sudoer {
    # $1 : username
    local username="${1}"
    $(which sudo) adduser "${username}"
    $(which sudo) usermod -aG sudo "${username}"
    $(which sudo) chown -R /home/"${username}"
    $(which sudo) chgrp -R /home/"${username}"
}


function repair_user_permissions {
    local user_name=""
    local user_array=( "$(cut -d: -f1 /etc/passwd)" )

    for user_name in "${user_array[@]}"; do
        echo "${user_name}"
        if [[ -d /home/"${user_name}" ]]; then
          $(which sudo) chown -R "${user_name}" /home/"${user_name}"
          $(which sudo) chgrp -R "${user_name}" /home/"${user_name}"
        fi
    done
}


function is_str1_in_str2 {
    # $1: search_string
    # $1: haystack
    local str1="${1}"
    local str2="${2}"
    if [[ $(echo "$str2}" | grep -c "${str1}" ) == "0" ]]; then
        echo "False"
    else
        echo "True"
    fi
}


function tests_is_str1_in_str2 {
	assert_equal "is_str1_in_str2 \"a\" \"aaa\"" "True"
	assert_equal "is_str1_in_str2 \"a a\" \"aaa aaa\"" "True"
	assert_equal "is_str1_in_str2 \"a b\" \"aaa aaa\"" "False"
}


function fail {
  clr_bold clr_red "${1}" >&2
  exit 1
}


function get_linux_release_name {
    local linux_release_name=`lsb_release --codename | cut -f2`
    echo "${linux_release_name}"
}

function banner_base {
    # $1: colours like "clr_bold clr_green" or "clr_red"
    # $2: banner_text
    # usage :
    # banner_base "clr_bold clr_green" "this is a test with${IFS}two lines !"

    local color=$1
    local banner_text=$2
    ${color} " "
    ${color} " "
    local sep="********************************************************************************"
    ${color} "${sep}"

    local line
    while IFS=$'\n' read -ra message; do
      for line in "${message[@]}"; do
          ${color} "* ${line}"
      done
    done <<< "${banner_text}"

    ${color} "${sep}"
}


function banner_base_test {
    # $1: colours like "clr_bold clr_green" or "clr_red"
    # $2: banner_text
    # usage :
    # banner_base "clr_bold clr_green" "this is a test with${IFS}two lines !"

    local color="${1}"
    local banner_text=${2}
    local msg_array=( ${2} )
    ${color} " "
    ${color} " "
    local sep="********************************************************************************"
    ${color} "${sep}"

    local line
      for line in "${msg_array[@]}"; do
          ${color} "* ${line}"
      done

    ${color} "${sep}"
}


function banner {
    # $1: banner_text
    # usage :
    # banner "this is a test wit '${IFS}'two lines !"

    local banner_text=$1
    banner_base "clr_bold clr_green" "${banner_text}"
}


function banner_warning {
    # $1: banner_text
    # usage :
    # banner "this is a test wit '${IFS}'two lines !"

    local banner_text=$1
    banner_base "clr_bold clr_red" "${banner_text}"
}


function linux_update {
    # update / upgrade linux and clean / autoremove
    clr_bold clr_green " "
    clr_bold clr_green "Linux Update"
    retry $(which sudo) apt-get update
    retry $(which sudo) apt-get upgrade -y
    retry $(which sudo) apt-get dist-upgrade -y
    retry $(which sudo) apt-get autoclean -y
    retry $(which sudo) apt-get autoremove -y
}


function wait_for_enter {
    # wait for enter - first parameter will be showed in a banner if present
    if [[ ! -z "$1" ]] ;
        then
            banner "${1}"
        fi
    read -p "Enter to continue, Cntrl-C to exit: "
}


function wait_for_enter_warning {
    # wait for enter - first parameter will be showed in a red banner if present
    if [[ ! -z "$1" ]] ;
        then
            banner_warning "${1}"
        fi
    read -p "Enter to continue, Cntrl-C to exit: "
}


function reboot {
    clr_bold clr_green " "
    clr_bold clr_green "Rebooting"
    $(which sudo) shutdown -r now
}


function get_is_package_installed {
    # $1: package name
    local package_name=$1
    if [[ $(dpkg -l ${package_name} 2> /dev/null | grep ${package_name} | cut -f 1 -d " ") == "ii" ]]; then
        echo "True"
    else
        echo "False"
    fi
}


function backup_file {
    # $1 : <file>
    # copies <file> to <file>.backup
    # copies <file> to <file>.original if <file>.original does not exist

    # if <file> exist
    local path_file="${1}"

    if [[ -f ${path_file} ]]; then
        local user=$(get_user_from_fileobject "${path_file}")
        local group=$(get_group_from_fileobject "${path_file}")

        $(which sudo) cp -f "${path_file}" "${path_file}.backup"
        $(which sudo) chown "${user}" "${path_file}.backup"
        $(which sudo) chgrp "${group}" "${path_file}.backup"
        # if <file>.original does NOT exist
        if [[ ! -f "${1}.original" ]]; then
            $(which sudo) cp -f "${path_file}" "${path_file}.original"
            $(which sudo) chown "${user}" "${path_file}.original"
            $(which sudo) chgrp "${group}" "${path_file}.original"
        fi
    fi
}


function remove_file {
    # $1 : <file>
    # removes <file>

    # if <file> exist
    if [[ -f "${1}" ]]; then
        $(which sudo) rm -f "${1}"
    fi
}


function get_prepend_auto_configuration_message_to_line {
    # $1: the line
    # $2: the comment character, usually "#" or ";"
    # usage: get_prepend_auto_configuration_message_to_line "test" "#"
    # output: # auto configured by bitranox at yyyy-mm-dd HH:MM:SS\ntest
    local line="${1}"
    local comment_char="${2}"
    local datetime=$(date '+%Y-%m-%d %H:%M:%S')
    local new_line="${comment_char} auto configured by bitranox scripts at ${datetime}\n${line}"
    echo "${new_line}"
}


function replace_or_add_lines_containing_string_in_file {
    # $1 : File
    # $2 : search string
    # $3 : new line to replace
    # $4 : comment_char in that file

    local path_file="${1}"
    local search_string="${2}"
    local new_line="${3}"
    local comment_char="${4}"
    local user=$(get_user_from_fileobject "${path_file}")
    local group=$(get_group_from_fileobject "${path_file}")
    local number_of_lines_found=$(cat "${path_file}" | grep -c "${search_string}")

    new_line=$(get_prepend_auto_configuration_message_to_line "${new_line}" "${comment_char}")

    if [[ $((number_of_lines_found)) > 0 ]]; then
        # replace lines if there
        $(which sudo) sed -i "/${search_string}/c\\${new_line}" "${path_file}"
    else
        # add line if not there
        $(which sudo) sh -c "echo \"${new_line}\" >> ${path_file}"
    fi
    $(which sudo) chown ${user} "${path_file}"
    $(which sudo) chgrp ${group} "${path_file}"
}


function get_is_hetzner_virtual_server {
    if [[ $(cat /sys/class/dmi/id/product_family | grep -c "Hetzner_vServer") != "0" ]]; then
        echo "True"
    else
        echo "False"
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
            eval "${call_args_array[@]:1}"
        else
            fail "${function_name} is not a known function name of ${library_name}"
        fi
    fi
}



function tests {
	# clr_green "no tests in ${0}"
	tests_is_str1_in_str2
}


## make it possible to call functions without source include
call_function_from_commandline "${0}" "${@}"
