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
    if ! is_lib_bash_up_to_date; then
      update_lib_bash
      # shellcheck disable=SC1090
      source "$(readlink -f "${BASH_SOURCE[0]}")"      # source ourself
      exit 0                                           # exit the old instance
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
