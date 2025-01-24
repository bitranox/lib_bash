#!/bin/bash

# Resources : https://devhints.io/bash
#

########################################################################################################################################################
# DEFAULT SETTINGS
########################################################################################################################################################
# 2025-01-21

function create_log_dir {
  local logfile="${1}"
  local log_dir
  log_dir=$(dirname "${logfile}")
  if [ ! -d "${log_dir}" ]; then
      mkdir -p "${log_dir}"
  fi
}

function set_default_settings {

    # Set default logging paths if not already defined or empty
    # Uses POSIX options expansion for safe default assignment
    # -----------------------------------------------------------
    # Main application log file (persistent)
    : "${LIB_BASH_LOGFILE:=$HOME/log/lib_bash/lib_bash.log}"
    create_log_dir "${LIB_BASH_LOGFILE}"

    # Temporary log storage (e.g., for session-specific logs)
    : "${LIB_BASH_LOGFILE_TMP:=$HOME/log/lib_bash/lib_bash_tmp.log}"
    create_log_dir "${LIB_BASH_LOGFILE_TMP}"

    # Error-specific log file (persistent errors)
    : "${LIB_BASH_LOGFILE_ERR:=$HOME/log/lib_bash/lib_bash_err.log}"
    create_log_dir "${LIB_BASH_LOGFILE_ERR}"

    # Temporary error log storage (ephemeral error tracking)
    : "${LIB_BASH_LOGFILE_ERR_TMP:=$HOME/log/lib_bash/lib_bash_err_tmp.log}"
    create_log_dir "${LIB_BASH_LOGFILE_ERR_TMP}"

    # -----------------------------------------------------------
    # Technical notes:
    # 1. The colon (:) is a null command that expands arguments
    # 2. ${VAR:=DEFAULT} syntax:
    #    - Sets VAR to DEFAULT if VAR is unset or empty
    #    - Preserves existing non-empty values
    # 3. All paths use /var/log/lib_bash/$(whoami)/ as default base directory
    # 4. Handles empty string values (e.g., explicitly set to "")
    # 5. No-op if variables already contain non-empty values
    # 6. make sure the user hae rights to write to the log directory
}

########################################################################################################################################################
# SET ASKPASS
########################################################################################################################################################
# 2025-01-21

function lib_bash_set_askpass {
sudo_askpass="$(command -v ssh-askpass)"
export SUDO_ASKPASS="${sudo_askpass}"
export NO_AT_BRIDGE=1  # get rid of ssh-askpass:25930 dbind-WARNING
}

########################################################################################################################################################
# SOURCE LIB BASH DEPENDENCIES
########################################################################################################################################################
# 2025-01-21

function source_lib_bash_dependencies {
    local my_dir
    # shellcheck disable=SC2164
    my_dir="$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )"  # this gives the full path, even for sourced scripts
    source "${my_dir}/lib_color.sh"
    source "${my_dir}/lib_retry.sh"
    source "${my_dir}/self_update.sh"
}

#########################################################################################################################################################
# LINUX UPDATE
########################################################################################################################################################
# 2025-01-21

function linux_update {
    exit_if_not_is_root
    # Update the list of available packages from the repositories
    # logc "$(apt-get update | tee /dev/tty)" "${PIPESTATUS[0]}"
    log "apt-get update"
    logc "$(apt-get update | tee /dev/tty)" "${PIPESTATUS[0]}" "NO_TTY"
    # Configure any packages that were unpacked but not yet configured
    log "dpkg --configure -a"
    logc "$(dpkg --configure -a | tee /dev/tty)" "${PIPESTATUS[0]}" "NO_TTY"
    # Attempt to fix broken dependencies and install missing packages
    log "apt-get --fix-broken install -y -o Dpkg::Options::=\"--force-confold\""
    logc "$(apt-get --fix-broken install -y -o Dpkg::Options::="--force-confold" | tee /dev/tty)" "${PIPESTATUS[0]}" "NO_TTY"
    # Upgrade all installed packages while keeping existing configuration files
    log "apt-get upgrade -y -o Dpkg::Options::=\"--force-confold\""
    logc "$(apt-get upgrade -y -o Dpkg::Options::="--force-confold" | tee /dev/tty)" "${PIPESTATUS[0]}" "NO_TTY"
    # Perform a distribution upgrade, which can include installing or removing packages
    # This also keeps existing configuration files
    log "apt-get dist-upgrade -y -o Dpkg::Options::=\"--force-confold\""
    logc "$(apt-get dist-upgrade -y -o Dpkg::Options::="--force-confold" | tee /dev/tty)" "${PIPESTATUS[0]}" "NO_TTY"
    # Clean up the local repository of retrieved package files to free up space
    log "apt-get autoclean -y"
    logc "$(apt-get autoclean -y | tee /dev/tty)" "${PIPESTATUS[0]}" "NO_TTY"
    # Remove unnecessary packages and purge their configuration files
    log "apt-get autoremove --purge -y"
    logc "$(apt-get autoremove --purge -y | tee /dev/tty)" "${PIPESTATUS[0]}" "NO_TTY"
    # Forcing Phased Updates : If the package is held back due to a phased update,
    # this command will still upgrade the package immediately, bypassing the phased rollout restrictions.
    # it will not mark it as manually installed
    # retry apt-get -s upgrade | grep "^Inst" | awk '{print $2}' | xargs -n 1 apt-get install --only-upgrade -y -o Dpkg::Options::="--force-confold"
    log "Installing phased updates"

    while true; do
      first_package_to_update=$(LANG=C apt-get -s upgrade | awk '/deferred due to phasing:|have been kept back:/ {while(1){getline; if(/^[0-9]/) break; for(i=1;i<=NF;i++) print $i}}' | sort -u | head -n1)
      if [ -z "$first_package_to_update" ]; then
        break
      fi
      reinstall_keep_marking "${first_package_to_update}"
    done

    # Repeat cleaning up of the package files after additional installations
    log "apt-get autoclean -y"
    logc "$(apt-get autoclean -y | tee /dev/tty)" "${PIPESTATUS[0]}" "NO_TTY"
    # Repeat removal of unnecessary packages after additional installations
    log "apt-get autoremove --purge -y"
    logc "$(apt-get autoremove --purge -y | tee /dev/tty)" "${PIPESTATUS[0]}" "NO_TTY"
}

########################################################################################################################################################
# REINSTALL PACKAGES AND KEEP MARKING MANUAL/AUTO
########################################################################################################################################################
# 2025-01-21

# Function to reinstall a list of packages while preserving their original marking (manual or auto)
function reinstall_keep_marking {
  local packages="${1}" # Accepts a space-separated list of package names as a single argument
  local pkg             # Variable to iterate over each package in the list

  exit_if_not_is_root
  # Loop through each package in the provided list
  for pkg in ${packages}; do
    # Check if the package is marked as manually installed
    if apt-mark showmanual | grep -q "^${pkg}$"; then
      # Reinstall the package and re-mark it as manually installed
      log "apt-get install --reinstall -o Dpkg::Options::=\"--force-confold\" -y ${pkg}"
      logc "$(apt-get install --reinstall -o Dpkg::Options::="--force-confold" -y "${pkg}" | tee /dev/tty)" "${PIPESTATUS[0]}"  "NO_TTY"
      apt-mark manual "${pkg}"
    else
      # Reinstall the package and re-mark it as automatically installed
      log "apt-get install --reinstall -o Dpkg::Options::=\"--force-confold\" -y ${pkg}"
      logc "$(apt-get install --reinstall -o Dpkg::Options::="--force-confold" -y "${pkg}" | tee /dev/tty)" "${PIPESTATUS[0]}"  "NO_TTY"
      apt-mark auto "${pkg}"
    fi
  done
}


########################################################################################################################################################
# PREPEND TEXT TO FILE
########################################################################################################################################################
# 2025-01-21

function lib_bash_prepend_text_to_file {
    local text="${1}"   # The text to prepend (first argument of the function)
    local file="${2}"   # The target file (second argument of the function)

    # Safety check: Does the file exist?
    if [[ ! -f "${file}" ]]; then
        log_err "lib_bash_prepend_text_to_file: File '${file}' does not exist."
        return 1
    fi

    # Safety check: Is the file readable?
    if [[ ! -r "${file}" ]]; then
        log_err "lib_bash_prepend_text_to_file: File '${file}' is not readable."
        return 1
    fi

    # Prepend the text to the file
    echo "${text}" | cat - "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
}

########################################################################################################################################################
# IS ROOT
########################################################################################################################################################
# 2025-01-21
function is_root {
    if [[ "${UID}" -ne 0 ]]; then
        return 1
    else
        return 0
    fi
}

function exit_if_not_is_root {
if ! is_root; then
    echo "lib_bash: You need to run this script or function as root."
    exit 1
fi
}


########################################################################################################################################################
# LOGGING
########################################################################################################################################################
function log {
  # Log to screen and logfiles
  # Arguments:
  #   1: message (required) - Text to log.
  #   2: options (optional) - "bold" force to log the command output as bold
  #                           "NO_TTY" to skip output to screen (but still to logfiles)
  # Usage : with piped commands : logc "$(apt-get update | tee /dev/tty)" "${PIPESTATUS[0]}" "NO_TTY"
  # with single commands : logc "$(echo "test")" $?

  local message="${1}"
  local options="${2}:-}"       # options, default to "" if not provided.: "bold", "NO_TTY"
  local logline

  # Process each line in the message
  while IFS= read -r line; do
    logline="$(date '+%Y-%m-%d %H:%M:%S') - $(whoami)@$(hostname -s): ${line}"
    if [[ "${options}" != *NO_TTY* ]]; then
        if [[ "${options}" == *bold* ]]; then
          clr_bold clr_green "${logline}"
        else
          clr_green "${logline}"
        fi
    fi
    [[ -n "${LIB_BASH_LOGFILE}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE}"
    [[ -n "${LIB_BASH_LOGFILE_TMP}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE_TMP}"
  done <<< "${message}"
}

function log_err {
  local message="${1}"
  local options="${2}:-}"       # options, default to "" if not provided.: "NO_TTY"
  local logline


  # Process each line in the message
  while IFS= read -r line; do
    logline="$(date '+%Y-%m-%d %H:%M:%S') - $(whoami)@$(hostname -s): ERROR [EE]: ${line}"
    if [[ "${options}" != *NO_TTY* ]]; then
      clr_bold clr_cyan "${logline}"
    fi
    [[ -n "${LIB_BASH_LOGFILE}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE}"
    [[ -n "${LIB_BASH_LOGFILE_TMP}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE_TMP}"
    [[ -n "${LIB_BASH_LOGFILE_ERR}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE_ERR}"
    [[ -n "${LIB_BASH_LOGFILE_ERR_TMP}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE_ERR_TMP}"
  done <<< "${message}"
}

function log_warn {
  local message="${1}"
  local options="${2}:-}"       # options, default to "" if not provided.: "NO_TTY"
  local logline


  # Process each line in the message
  while IFS= read -r line; do
    logline="$(date '+%Y-%m-%d %H:%M:%S') - $(whoami)@$(hostname -s): WARNING [WW]: ${line}"
    if [[ "${options}" != *NO_TTY* ]]; then
      clr_bold clr_yellow "${logline}"
    fi
    [[ -n "${LIB_BASH_LOGFILE}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE}"
    [[ -n "${LIB_BASH_LOGFILE_TMP}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE_TMP}"
    [[ -n "${LIB_BASH_LOGFILE_ERR}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE_ERR}"
    [[ -n "${LIB_BASH_LOGFILE_ERR_TMP}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE_ERR_TMP}"
  done <<< "${message}"
}

function logc {
  # Log the output of a command with support for error handling.
  # Arguments:
  #   1: output (required) - Text to log.
  #   2: exit_code (required) - Exit code of the last command. If 0, we log normally; otherwise, as an error.
  #   3: options (optional) - "ERR" force to log the command output as error, even if exit_code is 0.
  #                           "NO_TTY" to skip output to screen (but still to logfiles)
  # Usage : with piped commands : logc "$(apt-get update | tee /dev/tty)" "${PIPESTATUS[0]}" "NO_TTY"
  # with single commands : logc "$(echo "test")" $?

  local output="${1}"          # Output to be logged.
  local exit_code="${2:-0}"    # Exit code, default to 0 if not provided.
  local options="${3:-}"       # options, default to "" if not provided.: "ERR","NO_TTY","bold"

  # Return if output is empty.
  if [[ -z "${output}" ]]; then
    return 0
  fi

  # Log the exit code if it indicates an error.
  if [[ ${exit_code} -ne 0 ]]; then
    log_err "Exit code: ${exit_code}"
  fi

  # Log the output based on the log type or exit code.
  if [[ "${options}" == *ERR* ]] || [[ ${exit_code} -ne 0 ]]; then
    log_err "${output}" "${options}"
  else
    log "${output}" "${options}"
  fi
}

########################################################################################################################################################
# SEND EMAIL
########################################################################################################################################################
# 2025-01-21

function send_email {
    # Description:
    # This function sends an email to a specified recipient with a subject, content (from a file), and optional attachments.
    # Example :
    # send_email "recipient@example.com" "Subject of the Email" "/path/to/body_file.txt" "/path/to/attachment1" "/path/to/attachment2"

    local recipient="$1"  # The destination email address
    local subject="$2"    # The subject of the email
    local body_file="$3"  # File containing the email body
    # all remaining parameters are attachments

    # Validate the recipient email address
    if [[ -z "$recipient" ]]; then
        log_err "send_email: Recipient email address is missing."
        return 1
    fi

    # Validate the subject
    if [[ -z "$subject" ]]; then
        log_err "send_email: Subject is missing."
        return 1
    fi

    if [[ $# -lt 3 ]]; then
        log_err "send_email: Insufficient arguments provided. A recipient, subject, and body_file are required."
        return 1
    fi

    shift 3  # Ensure that all subsequent parameters are attachments, safe even if no extra arguments are provided
    local attachments=("$@")

    # Validate the number and size of attachments to avoid performance issues

    # Validate the body file
    if [[ -z "${body_file}" ]]; then
        log_err "send_email: body_file is missing."
        return 1
    fi

    if [[ ! -f "${body_file}" || ! -r "${body_file}" ]]; then
        log_err "send_email: body_file ${body_file} does not exist or is not readable."
        return 1
    fi

    # Validate attachments (if any)
    for attachment in "${attachments[@]}"; do
        # Handle filenames with spaces or special characters
        if [[ ! -f "${attachment}" || ! -r "${attachment}" ]]; then
            log_err "send_email: Attachment ${attachment} does not exist or is not readable."
            return 1
        fi
    done

    if ! command -v mutt &> /dev/null; then
        # Provide alternative instructions if 'mutt' is not available
        log_err "send_email: 'mutt' command not found. Please install it before proceeding."
        return 1
    fi

    # Send email with retry logic
    local max_retries=3
    local attempt=1

    while [[ $attempt -le $max_retries ]]; do
        if [[ ${#attachments[@]} -gt 0 ]]; then
            # Sending with attachments
            mutt -s "${subject}" -a "${attachments[@]}" -- "${recipient}" < "${body_file}" && \
            {
                return 0
            } || log_err "send_email: Error sending email (attempt $attempt): ${subject}. Attachments: ${attachments[*]}."
        else
            # Sending without attachments
            mutt -s "${subject}" -- "${recipient}" < "${body_file}" && \
            {
                return 0
            } || log_err "send_email: Error sending email (attempt $attempt): ${subject}."
        fi

        local backoff=$((2 ** attempt))
        sleep $backoff
        ((attempt++))
    done

    log_err "send_email: Failed to send email after $max_retries attempts: ${subject}."
    return 1
}

########################################################################################################################################################
# OLD HELPERS
########################################################################################################################################################

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


function wait_for_enter {
    # wait for enter - first options will be showed in a banner if present
    if [[ -n "$1" ]] ;
        then
            banner "${1}"
        fi
    read -rp "Enter to continue, Cntrl-C to exit: "
}


function wait_for_enter_warning {
    # wait for enter - first options will be showed in a red banner if present
    if [[ -n "$1" ]] ;
        then
            banner_warning "${1}"
        fi
    read -rp "Enter to continue, Cntrl-C to exit: "
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


function  is_program_available {
    # checkt ob ein programm verfügbar ist.
    # nicht für interne bash commands wie "ls"
    # $1: the program name to check
    local program_to_check="${1}"
    if [[ $(which "${program_to_check}") == "" ]]; then
      return 1
    else
      return 0
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


function  lib_bash_split {
    # $1 input
    # $2 separator ; the separator must not be <">
    # $3 index; - can be also -1 like in python
    if is_program_available python3; then
        local str_input="${1}"
        local str_separator="${2}"
        local num_index="${3}"
        echo "${str_input}" | python3 -c"import sys; sys.stdout.write(sys.stdin.read().split(\"${str_separator}\")[${num_index}])"
    else
        fail "python3 needs to be installed in order to use the function lib_bash_split"
        exit 1
    fi
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
    hostname_short="$(hostname -s)"
    echo "${hostname_short}"
}


function  lib_bash_path_exist {
    # $1 = Path to File or Directory
    local path_file="${1}"
    # shellcheck disable=SC2086
    if [[ -e "${path_file}" ]]; then
      return 0
    else
      return 1
    fi
}

########################################################################################################################################################
# INIT
########################################################################################################################################################

function LIB_BASH_MAIN {
  source_lib_bash_dependencies
  lib_bash_set_askpass
  set_default_settings
  ## make it possible to call functions without source include
  call_function_from_commandline "${0}" "${@}"
}

# update myself in a subshell - only once per session
if [[ ! -v LIB_BASH_IS_UP_TO_DATE ]]; then
    LIB_BASH_IS_UP_TO_DATE="true" &>/dev/null
    (
    # shellcheck disable=SC2034
    LIB_BASH_SELF_UPDATE_SELF=$(readlink -f "${BASH_SOURCE[0]}")
    # shellcheck disable=SC2034
    LIB_BASH_SELF_UPDATE_SELF_MAIN_FUNCTION="LIB_BASH_MAIN"
    source_lib_bash_dependencies
    lib_bash_set_askpass
    set_default_settings
    lib_bash_self_update "$@"
    )
else
    LIB_BASH_MAIN "$@"
fi


