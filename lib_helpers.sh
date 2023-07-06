#!/bin/bash

# Resources : https://devhints.io/bash
#

function default_actions {
sudo_askpass="$(command -v ssh-askpass)"
export SUDO_ASKPASS="${sudo_askpass}"
export NO_AT_BRIDGE=1  # get rid of ssh-askpass:25930 dbind-WARNING
}
default_actions

function  lib_bash_update_myself {
    local my_dir
    # shellcheck disable=SC2164
    my_dir="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"  # this gives the full path, even for sourced scripts
    # call the update script if not sourced and not already done in that session
    if [[ "${0}" == "${BASH_SOURCE[0]}" ]] && [[ -d "${BASH_SOURCE%/*}" ]] && [[ "${lib_bash_is_up_to_date_in_this_session}" != "True" ]]; then
        "${my_dir}"/install_or_update.sh
        lib_bash_is_up_to_date_in_this_session="True"
    fi
    }
lib_bash_update_myself

function include_dependencies {
    local my_dir
    # shellcheck disable=SC2164
    my_dir="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"  # this gives the full path, even for sourced scripts
    source "${my_dir}/lib_color.sh"
    source "${my_dir}/lib_retry.sh"
}
include_dependencies


function is_ok() {
    # for easy use : if is_ok; then ...
    # also preserves the returncode
    return $?
}


function get_own_script_name {
    # $1: bash_source, usually "${BASH_SOURCE}"
    local bash_source="${1}"
    readlink -f "${bash_source}"
}


function is_script_sourced {
    # $1: script_name "${0}"
    # $2: bash_source "${BASH_SOURCE}"
    local script_name="${1}"
    local bash_source="${2}"
    if [[ "${script_name}" != "${bash_source}" ]]; then
        return 0
    else
        return 1
    fi
}



function debug {
    # $1: should_debug: True/False
    # $2: debug_message
    local should_debug debug_message script_name
    should_debug="${1}"
    debug_message="${2}"
    script_name="$(get_own_script_name "${BASH_SOURCE[0]}")"

    if [[ "${should_debug}" == "True" ]]; then
        clr_blue "\
        ** DEBUG *****************************************************************************************************${IFS}\
        File          : ${script_name}${IFS}\
        Function      : ${FUNCNAME[ 1 ]}${IFS}\
        Caller        : ${FUNCNAME[ 2 ]}${IFS}\
        Debug Message : ${debug_message}${IFS}\
        **************************************************************************************************************"
    fi
}


function wait_for_file_to_be_created {
    # $1: file_name
    local file_name
    file_name="${1}"
    while [[ ! -f "${file_name}" ]]; do
        clr_blue "wait for ${file_name} to be created"
        sleep 1
    done
    sleep 1
}



function is_bash_function_declared {
    # checks if the function is declared
    # $1 : function name
    local function_name="${1}"
    declare -F "${function_name}" &>/dev/null && return 0 || return 1
}

function is_valid_command {
    #
    # $1 : any bash internal command, external command or function name
    local command
    command="${1}"

    if [[ "$(type -t "${command}")" == "builtin" ]]; then return 0; fi  # builtin command
    if is_bash_function_declared "${command}"; then return 0; fi        # declared function
    if [[ -n "$(type -p "${command}")" ]]; then return 0; fi            # external command
    return 1
}




function create_assert_failed_message {

	# $1 : test_command
	# $2 : expected
	# $3 : expected
    local script_name result test_command expected result

	test_command="${1}"
	expected="${2}"
	result="${3}"

    script_name="$(get_own_script_name "${BASH_SOURCE[0]}")"

	clr_red "\
    ** ASSERT ****************************************************************************************************"
	clr_reverse clr_cyan "\
	File     : ${script_name}"
	clr_cyan "\
	Test     : ${test_command}${IFS}\
	Result   : ${result}${IFS}\
	Expected : ${expected}"
	clr_red "\
	**************************************************************************************************************"
}



function check_assert_command_defined {
    local test_command expected result function_name
  	# $1 : test_command
	# $2 : expected
	test_command="${1}"
	expected="${2}"
    function_name="$(echo "${test_command}" | cut -d " " -f 1)"

    if ! is_valid_command "${function_name}"; then
        result="command \"${function_name}\" is not a declared function or a valid internal or external command "
        create_assert_failed_message "${test_command}" "${expected}" "${result}"
        return 1
    fi
}


function assert_equal {
	# $1 : test_command
	# $2 : expected
	local test_command expected result

	test_command="${1}"
	expected="${2}"
    check_assert_command_defined "${test_command}" "${expected}" || return 0
    result=$(eval "${1}")

	if [[ "${result}" != "${expected}" ]]; then
	    create_assert_failed_message "${test_command}" "\"${expected}\"" "\"${result}\""
    fi
}



function assert_contains {
	# $1 : test_command
	# $2 : expected
	local test_command expected result
	test_command="${1}"
	expected="${2}"
    check_assert_command_defined "${test_command}" "*${expected}*" || return 0
    result=$(eval "${1}")

	if [[ "${result}" != *"${expected}"* ]]; then
	    create_assert_failed_message "${test_command}" "\"*${expected}*\"" "\"${result}\""
	    fi
}



function assert_return_code {
	# $1 : test_command
	# $2 : expected
	local test_command expected result
	test_command="${1}"
	expected="${2}"
    check_assert_command_defined "${test_command}" "return code = ${expected}" || return 0
    eval "${1}"
    result="${?}"
	if [[ "${result}" -ne "${expected}" ]]; then
	    create_assert_failed_message "${test_command}" "return code = ${expected}" "return code = ${result}"
    fi
}


function assert_pass {
	# $1 : test_command
	local test_command result
	test_command="${1}"
    check_assert_command_defined "${test_command}" "return code = 0" || return 0
    eval "${1}"
    result="${?}"
	if [[ "${result}" -ne 0 ]]; then
	    create_assert_failed_message "${test_command}" "return code = 0" "return code = ${result}"
    fi
}


function assert_fail {
	# $1 : test_command
	local test_command result
	test_command="${1}"
    check_assert_command_defined "${test_command}" "return code > 0" || return 0
    eval "${1}"
    result="${?}"
	if [[ "${result}" -eq 0 ]]; then
	    create_assert_failed_message "${test_command}" "return code > 0" "return code = ${result}"
    fi
}


function cmd {
    # returns the command if present
    # $1 : the command
    command -v "${1}" 2>/dev/null
}


function get_log_file_name {
    # $1: script_name "${0}"
    # $2: bash_source "${BASH_SOURCE}"
    # usage : test_logfile=$(get_log_file_name "${0}" "${BASH_SOURCE}")
    # returns the name of the logfile : ${HOME}/log_usr_local_lib_<...>_001_000_<...>.log
    local script_name="${1}"
    local bash_source="${2}"
    local own_script_name_full=""
    local own_script_name_wo_extension=""
    local own_script_name_wo_extension_dashed=""
    local log_file_name=""

    own_script_name_full="$(get_own_script_name "${BASH_SOURCE[0]}")"
    own_script_name_wo_extension=${own_script_name_full%.*}
    own_script_name_wo_extension_dashed=$(echo "${own_script_name_wo_extension}" | tr '/' '_' )
    log_file_name="${HOME}"/log"${own_script_name_wo_extension_dashed}".log

    echo "${log_file_name}"
}


function get_user_from_fileobject {
    # $1: File or Directory
    # returns user
    local path_file="${1}"
    local user=""
    user=$(stat -c "%U$" "${path_file}")
    echo "${user}"
}

function get_group_from_fileobject {
    # $1: File or Directory
    # returns group
    local path_file="${1}"
    local group=""
    group=$(stat -c "%G" "${path_file}")
    echo "${group}"
}


function get_home_directory_from_username {
    # gets the home directory of a different user
    # without impersonating that user
    # $1: username
    local username homedirectory
    username="${1}"
    homedirectory="$(eval echo "~${username}")"
    echo "${homedirectory}"
}


function add_user_as_sudoer {
    # $1 : username
    local username="${1}"
    "$(cmd "sudo")" adduser "${username}"
    "$(cmd "sudo")" usermod -aG sudo "${username}"
    "$(cmd "sudo")" chown -R /home/"${username}"
    "$(cmd "sudo")" chgrp -R /home/"${username}"
}


function repair_user_permissions {
    local user_name=""
    local user_array=( "$(cut -d: -f1 /etc/passwd)" )

    for user_name in "${user_array[@]}"; do
        echo "${user_name}"
        if [[ -d /home/"${user_name}" ]]; then
          "$(cmd "sudo")" chown -R "${user_name}" /home/"${user_name}"
          "$(cmd "sudo")" chgrp -R "${user_name}" /home/"${user_name}"
        fi
    done
}


function is_str1_in_str2 {
    # $1: str1
    # $1: str2
    local str1="${1}"
    local str2="${2}"
    if [[ $(echo "$str2}" | grep -c "${str1}" ) == "0" ]]; then
        return 1
    else
        return 0
    fi
}


function fail {
  clr_bold clr_red "${1}" >&2
  exit 1
}

function nofail {
  clr_bold clr_red "${1}"
}


function get_linux_release_name {
    local linux_release_name=""
    linux_release_name=$(lsb_release -c -s)
    echo "${linux_release_name}"
}

function get_linux_release_number {
    local linux_release_number=""
    linux_release_number="$(lsb_release -r -s)"
    echo "${linux_release_number}"
}


function get_linux_release_number_major {
    local linux_release_number_major=""
    linux_release_number_major="$(get_linux_release_number | cut -d "." -f 1)"
    echo "${linux_release_number_major}"
}



function banner_base {
    # $1: colours like "clr_bold clr_green" or "clr_red"
    # $2: banner_text
    # usage :
    # banner_base "clr_bold clr_green" "this is a test with${IFS}two lines !"

    local color="${1}"
    local banner_text="${2}"
    local msg_array=( )
    # mapfile is not supported on OSX !
    # mapfile -t msg_array <<< "${2}"  # if it's multiple lines, each of which should be an element
    while IFS= read -r line; do
        msg_array+=("$line")
    done <<< "${2}"

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
    # banner "this is a test with '${IFS}'two lines !"

    local banner_text=$1
    banner_base "clr_bold clr_green" "${banner_text}"
}


function banner_warning {
    # $1: banner_text
    # usage :
    # banner_warning "this is a test with '${IFS}'two lines !"

    local banner_text=$1
    banner_base "clr_bold clr_red" "${banner_text}"
}


function linux_update {
    # update / upgrade linux and clean / autoremove
    clr_bold clr_green " "
    clr_bold clr_green "Linux Update"
    retry "$(cmd "sudo")" apt-get update
    retry "$(cmd "sudo")" apt-get upgrade -y
    retry "$(cmd "sudo")" apt-get dist-upgrade -y
    retry "$(cmd "sudo")" apt-get autoclean -y
    retry "$(cmd "sudo")" apt-get autoremove -y
}


function wait_for_enter {
    # wait for enter - first parameter will be showed in a banner if present
    if [[ -n "$1" ]] ;
        then
            banner "${1}"
        fi
    read -r -p "Enter to continue, Cntrl-C to exit: "
}


function wait_for_enter_warning {
    # wait for enter - first parameter will be showed in a red banner if present
    if [[ -n "$1" ]] ;
        then
            banner_warning "${1}"
        fi
    read -r -p "Enter to continue, Cntrl-C to exit: "
}


function reboot {
    clr_bold clr_green " "
    clr_bold clr_green "Rebooting"
    "$(cmd "sudo")" shutdown -r now
}


function is_package_installed {
    # $1: package name
    local package_name=$1
    if [[ $(dpkg -l "${package_name}" 2> /dev/null | grep "${package_name}" | cut -f 1 -d " ") == "ii" ]]; then
        return 0
    else
        return 1
    fi
}


function install_package_if_not_present {
    #$1: package
    #$2: silent  # will install silently when "True"
    local package silent
    package="${1}"
    silent="${2}"
    if ! is_package_installed "${package}"; then
        if [[ "${silent}" == "True" ]]; then
            retry_nofail "$(cmd "sudo")" apt-get install "${package}" -y  > /dev/null 2>&1
            if ! is_package_installed "${package}"; then
               fail "Installing ${package} failed"
            fi
        else
            retry "$(cmd "sudo")" apt-get install "${package}" -y
        fi
    fi
}


function uninstall_package_if_present {
    #$1: package
    #$2: silent  # will install silenty when "True"
    local package silent
    package="${1}"
    silent="${2}"

    if is_package_installed "${package}"; then
        if [[ "${silent}" == "True" ]]; then
            retry_nofail "$(cmd "sudo")" apt-get purge "${package}" -y > /dev/null 2>&1
            if is_package_installed "${package}"; then
               fail "Uninstalling ${package} failed"
            fi
        else
            retry "$(cmd "sudo")" apt-get purge "${package}" -y
        fi
    fi
}


function backup_file {
    # $1 : <file>
    # copies <file> to <file>.backup
    # copies <file> to <file>.original if <file>.original does not exist

    # if <file> exist
    local path_file="${1}"

    if [[ -f ${path_file} ]]; then
        local user group
        user=$(get_user_from_fileobject "${path_file}")
        group=$(get_group_from_fileobject "${path_file}")

        "$(cmd "sudo")" cp -f "${path_file}" "${path_file}.backup"
        "$(cmd "sudo")" chown "${user}" "${path_file}.backup"
        "$(cmd "sudo")" chgrp "${group}" "${path_file}.backup"
        # if <file>.original does NOT exist
        if [[ ! -f "${1}.original" ]]; then
            "$(cmd "sudo")" cp -f "${path_file}" "${path_file}.original"
            "$(cmd "sudo")" chown "${user}" "${path_file}.original"
            "$(cmd "sudo")" chgrp "${group}" "${path_file}.original"
        fi
    fi
}


function remove_file {
    # $1 : <file>
    # removes <file>

    # if <file> exist
    if [[ -f "${1}" ]]; then
        "$(cmd "sudo")" rm -f "${1}"
    fi
}


function get_prepend_auto_configuration_message_to_line {
    # $1: the line
    # $2: the comment character, usually "#" or ";"
    # usage: get_prepend_auto_configuration_message_to_line "test" "#"
    # output: # auto configured by bitranox at yyyy-mm-dd HH:MM:SS\ntest
    local line comment_char datetime new_line

    line="${1}"
    comment_char="${2}"
    datetime=$(date '+%Y-%m-%d %H:%M:%S')
    new_line="${comment_char} auto configured by bitranox configmagick scripts at ${datetime}\\n${line}"
    echo "${new_line}"
}


function replace_or_add_lines_containing_string_in_file {
    # $1 : File
    # $2 : search string
    # $3 : new line to replace
    # $4 : comment_char in that file
    local path_file search_string new_line comment_char user group number_of_lines_found

    path_file="${1}"
    search_string="${2}"
    new_line="${3}"
    comment_char="${4}"
    user=$(get_user_from_fileobject "${path_file}")
    group=$(get_group_from_fileobject "${path_file}")
    number_of_lines_found="$(grep -c "${search_string}" "${path_file}")"

    new_line=$(get_prepend_auto_configuration_message_to_line "${new_line}" "${comment_char}")

    if [[ $((number_of_lines_found)) -gt 0 ]]; then
        # replace lines if there
        "$(cmd "sudo")" sed -i "/${search_string}/c\\${new_line}" "${path_file}"
    else
        # add line if not there
        "$(cmd "sudo")" sh -c "echo \"${new_line}\" >> ${path_file}"
    fi
    "$(cmd "sudo")" chown "${user}" "${path_file}"
    "$(cmd "sudo")" chgrp "${group}" "${path_file}"
}


function is_hetzner_virtual_server {
    if [[ $(grep -c "Hetzner_vServer" /sys/class/dmi/id/product_family) != "0" ]]; then
        return 0
    else
        return 1
    fi
}


function call_function_from_commandline {
    # $1 : library_name ("${0}")
    # $2 : function_name ("${1}")
    # $3 : call_args ("${@}")
    local library_name="${1}"
    local function_name="${2}"
    local call_args_array=("${@}")

    if [[ -n ${function_name} ]]; then
        if is_bash_function_declared "${function_name}"; then
            "${call_args_array[@]:1}"
        else
            fail "${function_name} is not a known function name of ${library_name}"
        fi
    fi
}


function beep {
    echo -ne '\007'
}


function  lib_bash_upper {
    # $1 input
    local str_input="${1}"
    echo "${str_input^^}"
}

function  lib_bash_lower {
    # $1 input
    local str_input="${1}"
    echo "${str_input,,}"
}

function lib_bash_get_hostname_short {
    local hostname_short
    hostname_short=$(cut -d. -f1 <<< "${HOSTNAME}")
    echo "${hostname_short}"
}


## make it possible to call functions without source include
call_function_from_commandline "${0}" "${@}"
