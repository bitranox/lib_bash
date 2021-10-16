#!/bin/bash
MY_PATH=$(dirname "${0}")
cd ~ || exit 1

function default_actions {
sudo_askpass="$(command -v ssh-askpass)"
export SUDO_ASKPASS="${sudo_askpass}"
export NO_AT_BRIDGE=1  # get rid of ssh-askpass:25930 dbind-WARNING
}
default_actions

function include_dependencies {
    source /usr/local/lib_bash/lib_color.sh
    source /usr/local/lib_bash/lib_retry.sh
    source /usr/local/lib_bash/lib_helpers.sh
    source /usr/local/lib_bash/install_or_update.sh
    # call the update script if not sourced and not already done in that session
    if [[ "${0}" == "${BASH_SOURCE[0]}" ]] && [[ -d "${BASH_SOURCE%/*}" ]] && [[ "${lib_bash_is_up_to_date_in_this_session}" != "True" ]]; then
        /usr/local/lib_bash/install_or_update.sh
        lib_bash_is_up_to_date_in_this_session="True"
    fi
}
include_dependencies


clr_green "Hello World"
clr_red   "Hello World"
clr_blue  "Hello World"
clr_cyan  "Hello World"

read -rp "Finished, press any key to continue... " -n1 -s
echo ""
cd "${MY_PATH}" || exit 1
exit 0
