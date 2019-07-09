#!/bin/bash

function include_dependencies {
    source /usr/lib/lib_bash/lib_color.sh
    source /usr/lib/lib_bash/lib_retry.sh
    source /usr/lib/lib_bash/lib_helpers.sh
}


function install_dialog {
    if [[ "$(get_is_package_installed dialog)" == "False" ]]; then
        retry $(get_sudo_command) apt-get install dialog -y > /dev/null 2>&1
    fi
}

function install_git {
    if [[ "$(get_is_package_installed git)" == "False" ]]; then
        retry $(get_sudo_command) apt-get install git -y > /dev/null 2>&1
    fi
}

function install_net_tools {
    if [[ "$(get_is_package_installed net-tools)" == "False" ]]; then
        retry $(get_sudo_command) apt-get install net-tools -y > /dev/null 2>&1
    fi
}

function uninstall_whoopsie {
    local sudo_command=$(get_sudo_command)
    if [[ "$(get_is_package_installed whoopsie)" == "True" ]]; then
        retry ${sudo_command} apt-get purge whoopsie -y > /dev/null 2>&1
    fi
    if [[ "$(get_is_package_installed libwhoopsie0)" == "True" ]]; then
        retry ${sudo_command} apt-get purge libwhoopsie0 -y > /dev/null 2>&1
    fi
    if [[ "$(get_is_package_installed libwhoopsie-preferences0)" == "True" ]]; then
        retry ${sudo_command} apt-get purge libwhoopsie-preferences0 -y > /dev/null 2>&1
    fi
}

function uninstall_apport {
    if [[ "$(get_is_package_installed apport)" == "True" ]]; then
        retry $(get_sudo_command) apt-get purge apport -y > /dev/null 2>&1
    fi
}


function install_essentials {
    # update / upgrade linux and clean / autoremove
    clr_bold clr_green "Installiere Essentielles am Host, entferne Apport und Whoopsie"
    install_net_tools
    install_git
    install_dialog
    uninstall_whoopsie
    uninstall_apport
}

function install_and_update_language_packs {
    # install language pack and install language files for applications
    # returns Error 100 if reboot is needed (in variable $?)
    banner "Install and Update Language Packs"
    local sudo_command=$(get_sudo_command)
    local reboot_needed="False"

    if [[ "$(get_is_package_installed language-pack-de)" == "False" ]]; then
        retry ${sudo_command} apt-get install language-pack-de -y
        reboot_needed="True"
    fi
    if [[ "$(get_is_package_installed language-pack-de-base)" == "False" ]]; then
        retry ${sudo_command} apt-get install language-pack-de-base -y
        reboot_needed="True"
    fi
    if [[ "$(get_is_package_installed manpages-de)" == "False" ]]; then
        retry ${sudo_command} apt-get install manpages-de -y
        reboot_needed="True"
    fi
    if [[ "$(get_is_package_installed language-pack-gnome-de)" == "False" ]]; then
        retry ${sudo_command} apt-get install language-pack-gnome-de -y
        reboot_needed="True"
    fi

    ${sudo_command} update-locale LANG=\"de_AT.UTF-8\" LANGUAGE=\"de_AT:de\"


    local language_support_list=$(check-language-support -l de)
    local language_support
    while IFS=$'\n' read -ra language_support_array; do
      for language_support in "${language_support_array[@]}"; do
          if [[ "$(get_is_package_installed ${language_support})" == "False" ]]; then
            retry ${sudo_command} apt-get install ${language_support} -y
            reboot_needed="True"
          fi
      done
    done <<< "${language_support_list}"

    if [[ ${reboot_needed} == "True" ]]; then
        return 100
    else
        return 0
    fi
}


include_dependencies  # we need to do that via a function to have local scope of my_dir

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
