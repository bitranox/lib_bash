#!/bin/bash

function include_dependencies {
    local my_dir="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"  # this gives the full path, even for sourced scripts
    source "${my_dir}/lib_color.sh"
}

include_dependencies  # we need to do that via a function to have local scope of my_dir


function fail {
  clr_bold clr_red "${1}" >&2
  exit 1
}

function get_linux_codename {
    local linux_codename=`lsb_release --codename | cut -f2`
    echo "${linux_codename}"
}

function banner {
    clr_bold clr_green " "
    clr_bold clr_green " "
    local sep="********************************************************************************"
    clr_bold clr_green "${sep}"
    clr_bold clr_green "* ${1}"
    clr_bold clr_green "${sep}"
}


function banner_warning {
    clr_bold clr_red " "
    clr_bold clr_red " "
    local sep="********************************************************************************"
    clr_bold clr_red "${sep}"
    clr_bold clr_red "* ${1}"
    clr_bold clr_red "${sep}"
}

function linux_update {
    # update / upgrade linux and clean / autoremove
    clr_bold clr_green " "
    clr_bold clr_green "Linux Update"
    retry sudo apt-get update
    retry sudo apt-get upgrade -y
    retry sudo apt-get dist-upgrade -y
    retry sudo apt-get autoclean -y
    retry sudo apt-get autoremove -y
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
    sudo shutdown -r now
}


function backup_file {
    # $1 : <file>
    # copies <file> to <file>.backup
    # copies <file> to <file>.original if <file>.original does not exist

    # if <file> exist
    if [[ -f "${1}" ]]; then
        # copy <file>.original to <file>.backup
        sudo cp -f "${1}" "${1}.backup"
        # if <file>.original does NOT exist
        if [[ ! -f "${1}.original" ]]; then
            sudo cp -f "${1}" "${1}.original"
        fi
    fi
}


function remove_file {
    # $1 : <file>
    # removes <file>

    # if <file> exist
    if [[ -f "${1}" ]]; then
        sudo rm -f "${1}"
    fi
}


function replace_or_add_lines_containing_string_in_file {
    # $1 : File
    # $2 : search string
    # $3 : new line to replace
    local path_file=$1
    local search_string=$2
    local new_line=$3
    local number_of_lines_found=$(cat ${path_file} | grep -c ${search_string})
    if [[ $((number_of_lines_found)) > 0 ]]; then
        # replace lines if there
        sudo sed -i "/${search_string}/c\\${new_line}" ${path_file}
    else
        # add line if not there
        sudo sh -c "echo \"${new_line}\" >> ${path_file}"
    fi
}


## make it possible to call functions without source include
# Check if the function exists (bash specific)
if [[ ! -z "$1" ]]
    then
        if declare -f "${1}" > /dev/null
        then
          # call arguments verbatim
          "$@"
        else
          # Show a helpful error
          function_name="${1}"
          library_name="${0}"
          fail "\"${function_name}\" is not a known function name of \"${library_name}\""
        fi
	fi
