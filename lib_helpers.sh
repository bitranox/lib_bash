#!/bin/bash

# function include_dependencies {
#     my_dir="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"  # this gives the full path, even for sourced scripts
#     source "${my_dir}/lib_color.sh"
#     source "${my_dir}/lib_helpers.sh"
#
# }
#
# include_dependencies  # we need to do that via a function to have local scope of my_dir

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




function update_myself {
    /usr/local/lib_bash/install_or_update.sh "${@}" || exit 0              # exit old instance after updates
}


function include_dependencies {
    source /usr/local/lib_bash/lib_color.sh
}

# we need to do this in a function otherwise parameter {@} will be passed !
# and we need to do it here, before another library overwrites the function include_dependencies
include_dependencies

function get_user_and_group {
    # $1: File or Directory
    # returns user${IFS}group  ${IFS} is the default seperator

    local path_file=${1}
    local user_group=$(stat -c "%U${IFS}%G" ${path_file})
    echo "${user_group}"
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
    local user_list=$(cut -d: -f1 /etc/passwd)
    local user_name=""

    while IFS=$'\n' read -ra user_array; do
      for user_name in "${user_array[@]}"; do
          if [[ -d /home/"${user_name}" ]]; then
            $(which sudo) chown -R "${user_name}" /home/"${user_name}"
            $(which sudo) chgrp -R "${user_name}" /home/"${user_name}"
            reboot_needed="True"
          fi
      done
    done <<< "${user_list}"

}

function set_user_and_group {
    # $1: File or Directory
    # $2: user${IFS}group
    local path_file="${1}"
    local user_group="${2}"
    read -r -a array <<< "${user_group}"
    local new_user="${array[0]}"
    local new_group="${array[1]}"
    $(which sudo) chown "${new_user}" "${path_file}"
    $(which sudo) chgrp "${new_group}" "${path_file}"
}

function get_is_string1_in_string2 {
    # $1: search_string
    # $1: haystack
    local search_string="${1}"
    local haystack="${2}"
    if [[ $(echo "$haystack}" | grep -c ${search_string}) == "0" ]]; then
        echo "False"
    else
        echo "True"
    fi
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
    if [[ $(dpkg -l ${package_name} 2> /dev/null | grep ${package_name} | cut -f 1 -d " ") == "un" ]]; then
        echo "False"
    else
        echo "True"
    fi
}


function backup_file {
    # $1 : <file>
    # copies <file> to <file>.backup
    # copies <file> to <file>.original if <file>.original does not exist

    # if <file> exist
    local path_file=$1

    if [[ -f "${path_file}" ]]; then
        # copy <file>.original to <file>.backup
        local user_and_group=$(get_user_and_group ${path_file})
        $(which sudo) cp -f "${path_file}" "${path_file}.backup"
        set_user_and_group "${path_file}.backup" ${user_and_group}
        # if <file>.original does NOT exist
        if [[ ! -f "${1}.original" ]]; then
            $(which sudo) cp -f "${path_file}" "${path_file}.original"
            set_user_and_group "${path_file}.original" ${user_and_group}
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
    local line="{$1}"
    local comment_char="{$2}"
    local datetime=$(date '+%Y-%m-%d %H:%M:%S')
    local new_line="${comment_char} auto configured by bitranox scripts at ${datetime}\n${line}"
}


function replace_or_add_lines_containing_string_in_file {
    # $1 : File
    # $2 : search string
    # $3 : new line to replace
    # $4 : comment_char in that file

    local path_file="{$1}"
    local search_string="{$2}"
    local new_line="{$3}"
    local comment_char="{$4}"
    local user_and_group=$(get_user_and_group ${path_file})
    local number_of_lines_found=$(cat ${path_file} | grep -c ${search_string})

    new_line=$(get_prepend_auto_configuration_message_to_line ${new_line} ${comment_char})

    if [[ $((number_of_lines_found)) > 0 ]]; then
        # replace lines if there
        $(which sudo) sed -i "/${search_string}/c\\${new_line}" ${path_file}
    else
        # add line if not there
        $(which sudo) sh -c "echo \"${new_line}\" >> ${path_file}"
    fi
    set_user_and_group "${path_file}" ${user_and_group}
}


function get_is_hetzner_virtual_server {
    if [[ $(cat /sys/class/dmi/id/product_family | grep -c "Hetzner_vServer") != "0" ]]; then
        echo "True"
    else
        echo "False"
    fi
}


## make it possible to call functions without source include
# Check if the function exists (bash specific)
if [[ ! -z "$1" ]]
    then
        if declare -f "${1}" > /dev/null
        then
          # call arguments verbatim
          update_myself ${0} ${@}  > /dev/null 2>&1  # suppress messages here, not to spoil up answers from functions
          "$@"
        else
          update_myself ${0} ${@}  > /dev/null 2>&1  # suppress messages here, not to spoil up answers from functions
          # Show a helpful error
          function_name="${1}"
          library_name="${0}"
          fail "\"${function_name}\" is not a known function name of \"${library_name}\""
        fi
	fi
