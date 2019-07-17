#!/bin/bash

export bitranox_debug_global="${bitranox_debug_global}"
export debug_lib_bash="False"


function get_my_dir {
    local mydir
    mydir="${BASH_SOURCE%/*}"
    if [[ ! -d "${mydir}" ]]; then mydir="${PWD}"; fi
    echo "${mydir}"
}


function include_dependencies {
    local mydir=""
    mydir="$(get_my_dir)"
    source "${mydir}/lib_color.sh"
}

include_dependencies


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

    local script_name=""
    script_name="$(get_own_script_name "${BASH_SOURCE[0]}")"

    if [[ "${bitranox_debug_global}" == "True" ]]; then
        should_debug="True"
    fi

    if [[ "${should_debug}" == "True" ]]; then clr_blue "\
    ** DEBUG *****************************************************************************************************${IFS}\
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

	local script_name=""
    local result=""

    script_name="$(get_own_script_name "${BASH_SOURCE[0]}")"
    result=$(eval "${1}")

	if [[ "${result}" != "${expected}" ]]; then clr_blue "\
    ** ASSERT ****************************************************************************************************"
	clr_reverse clr_cyan "\
	File     : ${script_name}"
	clr_cyan "\
	Test     : ${test}${IFS}\
	Result   : ${result}${IFS}\
	Expected : ${expected}"
	clr_red "\
	**************************************************************************************************************"; fi
}


function get_sudo {
    # on some platforms we dont have sudo
    # returns the command for sudo or nothing
    command -v sudo 2>/dev/null
}


function get_log_file_name {
    # $1: script_name "${0}"
    # $2: bash_source "${BASH_SOURCE}"
    # usage : test=$(get_log_file_name "${0}" "${BASH_SOURCE}")
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


function add_user_as_sudoer {
    # $1 : username
    local username="${1}"
    "$(get_sudo)" adduser "${username}"
    "$(get_sudo)" usermod -aG sudo "${username}"
    "$(get_sudo)" chown -R /home/"${username}"
    "$(get_sudo)" chgrp -R /home/"${username}"
}


function repair_user_permissions {
    local user_name=""
    local user_array=( "$(cut -d: -f1 /etc/passwd)" )

    for user_name in "${user_array[@]}"; do
        echo "${user_name}"
        if [[ -d /home/"${user_name}" ]]; then
          "$(get_sudo)" chown -R "${user_name}" /home/"${user_name}"
          "$(get_sudo)" chgrp -R "${user_name}" /home/"${user_name}"
        fi
    done
}


function is_str1_in_str2 {
    # $1: str1
    # $1: str2
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
    mapfile -t msg_array <<< "${2}"  # if it's multiple lines, each of which should be an element
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
    retry "$(get_sudo)" apt-get update
    retry "$(get_sudo)" apt-get upgrade -y
    retry "$(get_sudo)" apt-get dist-upgrade -y
    retry "$(get_sudo)" apt-get autoclean -y
    retry "$(get_sudo)" apt-get autoremove -y
}


function wait_for_enter {
    # wait for enter - first parameter will be showed in a banner if present
    if [[ ! -z "$1" ]] ;
        then
            banner "${1}"
        fi
    read -r -p "Enter to continue, Cntrl-C to exit: "
}


function wait_for_enter_warning {
    # wait for enter - first parameter will be showed in a red banner if present
    if [[ ! -z "$1" ]] ;
        then
            banner_warning "${1}"
        fi
    read -r -p "Enter to continue, Cntrl-C to exit: "
}


function reboot {
    clr_bold clr_green " "
    clr_bold clr_green "Rebooting"
    "$(get_sudo)" shutdown -r now
}


function get_is_package_installed {
    # $1: package name
    local package_name=$1
    if [[ $(dpkg -l "${package_name}" 2> /dev/null | grep "${package_name}" | cut -f 1 -d " ") == "ii" ]]; then
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
        local user group
        user=$(get_user_from_fileobject "${path_file}")
        group=$(get_group_from_fileobject "${path_file}")

        "$(get_sudo)" cp -f "${path_file}" "${path_file}.backup"
        "$(get_sudo)" chown "${user}" "${path_file}.backup"
        "$(get_sudo)" chgrp "${group}" "${path_file}.backup"
        # if <file>.original does NOT exist
        if [[ ! -f "${1}.original" ]]; then
            "$(get_sudo)" cp -f "${path_file}" "${path_file}.original"
            "$(get_sudo)" chown "${user}" "${path_file}.original"
            "$(get_sudo)" chgrp "${group}" "${path_file}.original"
        fi
    fi
}


function remove_file {
    # $1 : <file>
    # removes <file>

    # if <file> exist
    if [[ -f "${1}" ]]; then
        "$(get_sudo)" rm -f "${1}"
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
        "$(get_sudo)" sed -i "/${search_string}/c\\${new_line}" "${path_file}"
    else
        # add line if not there
        "$(get_sudo)" sh -c "echo \"${new_line}\" >> ${path_file}"
    fi
    "$(get_sudo)" chown "${user}" "${path_file}"
    "$(get_sudo)" chgrp "${group}" "${path_file}"
}


function get_is_hetzner_virtual_server {
    if [[ $(grep -c "Hetzner_vServer" /sys/class/dmi/id/product_family) != "0" ]]; then
        echo "True"
    else
        echo "False"
    fi
}


function check_if_bash_function_is_declared {
    # $1 : function name
    local function_name="${1}"
    declare -F "${function_name}" &>/dev/null && echo "True" || echo "False"
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
            "${call_args_array[@]:1}"
        else
            fail "${function_name} is not a known function name of ${library_name}"
        fi
    fi
}


## make it possible to call functions without source include
call_function_from_commandline "${0}" "${@}"
