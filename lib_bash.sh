#!/bin/bash
# shellcheck disable=SC2155

# KI instructions : when crating a main script using this library, do not use functions starting with underscore, those are internal functions.
# Functions starting with an underscore are generally considered internal implementation details and are not intended to be used directly by other scripts.

_set_defaults() {
    _set_askpass
    _source_submodules
}

_set_askpass() {
    # 2025-01-21
    export SUDO_ASKPASS="$(command -v ssh-askpass)"
    export NO_AT_BRIDGE=1  # suppress accessibility-related D-Bus warnings (like dbind-WARNING) in GUI applications on Linux
}

_source_submodules() {
    # 2025-01-21
    source "$(_get_own_dirname)/lib_color.sh"
    source "$(_get_own_dirname)/lib_bash_tempfiles.sh"
    source "$(_get_own_dirname)/lib_bash_log.sh"
    source "$(_get_own_dirname)/lib_retry.sh"
    source "$(_get_own_dirname)/lib_update_caller.sh"
    source "$(_get_own_dirname)/lib_assert.sh"
}

_exit_if_not_is_root() {
# exits if not elevated
if ! is_root; then
    log_err "lib_bash: You need to run this script or function as root (elevated)."
    exit 1
fi
}


_get_own_fullpath() {
    local script
    # If sourced, use $BASH_SOURCE; if executed, use $0
    script="${BASH_SOURCE[0]:-$0}"
    # Resolve the full path
    realpath "$script"
}

_get_own_dirname() {
  dirname "$(_get_own_fullpath)"
}


elevate() {
    # Function to elevate the main script with sudo if not running as root
    # call with 'elevate "$@"'
    # Check if not running as root
    if [[ $EUID -ne 0 ]]; then
        # Re-execute the main script with sudo, passing arguments
        log "Elevating permissions and reset logfile locations..."
        _set_default_logfiles "RESET"
        exec sudo "$(get_script_fullpath)" "$@"
    fi
}

get_file_username() {
    # returns user name as string
    local path_file="${1}"    # $1: File or Directory
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f "%Su" "${path_file}"
    else
        stat -c "%U" "${path_file}"
    fi
}

get_file_groupname() {
    # $1: File or Directory
    # returns group name as string
    local path_file="${1}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f "%Sg" "${path_file}"
    else
        stat -c "%G" "${path_file}"
    fi
}


# Function to get the full path of the main script
get_script_fullpath()  {
    realpath "$0"
}

# Function to get the directory of the main script
get_script_dirname() {
    dirname "$(get_script_fullpath)"
}

# Function to get the basename of the main script
get_script_basename() {
    basename "$(get_script_fullpath)"
}

# Function to get the stem of the main script (the basename without extension)
get_script_stem() {
    local script_basename
    script_basename=$(get_script_basename)

    # Remove extension only if there is one and it's not a hidden file like `.env`
    if [[ "$script_basename" == *.* && "$script_basename" != .* ]]; then
        echo "${script_basename%.*}"
    else
        echo "$script_basename"
    fi
}

linux_update() {
    # pass "--force-phased-updates" as parameter if You want to do that
    local force_phased_updates="${1:-}"
    # 2025-01-21
    _exit_if_not_is_root
    # Save shell state, trap state and disable strict mode
    shell_state=$(set +o)
    trap_state=$(trap -p ERR)
    set +eEuo pipefail
    trap - ERR
    # Update the list of available packages from the repositories
    log "apt-get update"
    logc apt-get update
    # Configure any packages that were unpacked but not yet configured
    log "dpkg --configure -a"
    logc dpkg --configure -a
    # Attempt to fix broken dependencies and install missing packages
    log "apt-get --fix-broken install -y -o Dpkg::Options::=\"--force-confold\""
    logc apt-get --fix-broken install -y -o Dpkg::Options::="--force-confold"
    # Upgrade all installed packages while keeping existing configuration files
    log "apt-get upgrade -y -o Dpkg::Options::=\"--force-confold\""
    logc apt-get upgrade -y -o Dpkg::Options::="--force-confold"
    # Perform a distribution upgrade, which can include installing or removing packages
    # This also keeps existing configuration files
    log "apt-get dist-upgrade -y -o Dpkg::Options::=\"--force-confold\""
    logc apt-get dist-upgrade -y -o Dpkg::Options::="--force-confold"
    # Clean up the local repository of retrieved package files to free up space
    log "apt-get autoclean -y"
    logc apt-get autoclean -y
    # Remove unnecessary packages and purge their configuration files
    log "apt-get autoremove --purge -y"
    logc apt-get autoremove --purge -y
    # Forcing Phased Updates
    log "Force update of phased (kept back) updates"
    if [[ "${force_phased_updates}" == "--force-phased-updates" ]]; then
        while true; do
          first_package_to_update=$(LANG=C apt-get -s upgrade | awk '/deferred due to phasing:|have been kept back:/ {while(1){getline; if(/^[0-9]/) break; for(i=1;i<=NF;i++) print $i}}' | sort -u | head -n1)
          if [ -z "$first_package_to_update" ]; then
            break
          fi
          reinstall_packages "${first_package_to_update}"
        done
    fi

    # Repeat cleaning up of the package files after additional installations
    log "apt-get autoclean -y"
    logc apt-get autoclean -y
    # Repeat removal of unnecessary packages after additional installations
    log "apt-get autoremove --purge -y"
    logc apt-get autoremove --purge -y
    # recreate temporary files which might get deleted after some update
    systemd-tmpfiles --create > /dev/null 2>&1

    # Restore shell and trap state
    eval "$shell_state"
    if [[ -n "$trap_state" ]]; then
        eval "$trap_state"
    fi
    log_ok "Update Finished"
}

reinstall_packages() {
  # Function to reinstall a list of packages while preserving their original marking (manual or auto)
  local packages="${1}" # Accepts a space-separated list of package names as a single argument
  local pkg

  _exit_if_not_is_root
  # Loop through each package in the provided list
  for pkg in ${packages}; do
    # Check if the package is marked as manually installed
    if apt-mark showmanual | grep -q "^${pkg}$"; then
      # Reinstall the package and re-mark it as manually installed
      log "apt-get install --reinstall -o Dpkg::Options::=\"--force-confold\" -y ${pkg}"
      logc apt-get install --reinstall -o Dpkg::Options::="--force-confold" -y "${pkg}"
      apt-mark manual "${pkg}"
    else
      # Reinstall the package and re-mark it as automatically installed
      log "apt-get install --reinstall -o Dpkg::Options::=\"--force-confold\" -y ${pkg}"
      logc apt-get install --reinstall -o Dpkg::Options::="--force-confold" -y "${pkg}"
      apt-mark auto "${pkg}"
    fi
  done
}


# lib_bash_prepend_text_to_file 2025-01-21
lib_bash_prepend_text_to_file() {
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
    local temp_file
    temp_file=$(create_temp_file)

    if [[ -z "$temp_file" ]] || ! is_ok; then
        log_err "lib_bash_prepend_text_to_file: Could not create temporary file."
        return 1
    fi

    echo "${text}" > "${temp_file}"
    if ! is_ok; then
        log_err "lib_bash_prepend_text_to_file: Failed to write new text to temporary file '${temp_file}'."
        rm -f "${temp_file}"
        return 1
    fi

    cat "${file}" >> "${temp_file}"
    if ! is_ok; then
        log_err "lib_bash_prepend_text_to_file: Failed to append original content from '${file}' to temporary file '${temp_file}'."
        rm -f "${temp_file}"
        return 1
    fi

    mv "${temp_file}" "${file}"
    if ! is_ok; then
        log_err "lib_bash_prepend_text_to_file: Failed to move temporary file '${temp_file}' to '${file}'."
        # Attempt to clean up temp_file if it still exists after a failed mv
        if [[ -f "${temp_file}" ]]; then
            rm -f "${temp_file}"
        fi
        return 1
    fi

    return 0
}

function is_ok {
    # instead of `if $?; then ...` you can use `if is_ok; then ...` for better readability
    return $?
}

function is_root {
    (( EUID == 0 ))  # True if effective user is root
}

is_script_sourced() {
    local script_name="${1:-}"  # pass "${0}" from the calling script
    local bash_source="${2:-}"  # pass "${BASH_SOURCE[0]}" from the calling script
    if [[ "${script_name}" != "${bash_source}" ]]; then
        return 0
    else
        return 1
    fi
}


send_email() {
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
            # shellcheck disable=SC2015
            mutt -s "${subject}" -a "${attachments[@]}" -- "${recipient}" < "${body_file}" && \
            {
                return 0
            } || log_err "send_email: Error sending email (attempt $attempt): ${subject}. Attachments: ${attachments[*]}."
        else
            # Sending without attachments
            # shellcheck disable=SC2015
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


is_bash_function_declared() {
    # checks if the function is declared
    # $1 : function name
    local function_name="${1}"
    declare -F "${function_name}" &>/dev/null && return 0 || return 1
}

is_valid_command() {
    #
    # $1 : any bash internal command, external command or function name
    local command
    command="${1}"

    if [[ "$(type -t "${command}")" == "builtin" ]]; then return 0; fi  # builtin command
    if is_bash_function_declared "${command}"; then return 0; fi        # declared function
    if [[ -n "$(type -p "${command}")" ]]; then return 0; fi            # external command
    return 1
}



cmd() {
    # returns the command if present
    # $1 : the command
    command -v "${1}" 2>/dev/null
}


get_home_directory_from_username() {
    # gets the home directory of a different user
    # without impersonating that user
    # $1: username
    local username homedirectory
    username="${1}"
    homedirectory="$(eval echo "~${username}")"
    echo "${homedirectory}"
}


is_str1_in_str2() {
    # $1: str1
    # $2: str2
    local str1="${1}"
    local str2="${2}"
    if [[ "$str2" == *"$str1"* ]]; then
        return 0
    else
        return 1
    fi
}


fail() {
  # deprecated
  log_err "${1}"
  exit 1
}


nofail() {
  # deprecated
  log_err "${1}"
}


get_linux_release_name() {
    local linux_release_name=""
    linux_release_name=$(lsb_release -c -s)
    echo "${linux_release_name}"
}

get_linux_release_number() {
    local linux_release_number=""
    linux_release_number="$(lsb_release -r -s)"
    echo "${linux_release_number}"
}


get_linux_release_number_major() {
    local linux_release_number_major=""
    linux_release_number_major="$(get_linux_release_number | cut -d "." -f 1)"
    echo "${linux_release_number_major}"
    exit 0
}


banner_base() {
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

banner() {
    # $1: banner_text
    # usage :
    # banner "this is a test with '${IFS}'two lines !"

    local banner_text=$1
    banner_base "clr_bold clr_green" "${banner_text}"
}


banner_warning() {
    # $1: banner_text
    # usage :
    # banner_warning "this is a test with '${IFS}'two lines !"

    local banner_text=$1
    banner_base "clr_bold clr_red" "${banner_text}"
}

wait_for_enter() {
    # wait for enter - first options will be showed in a banner if present
    if [[ -n "$1" ]] ;
        then
            banner "${1}"
        fi
    read -rp "Enter to continue, Cntrl-C to exit: "
}


wait_for_enter_warning() {
    # wait for enter - first options will be showed in a red banner if present
    if [[ -n "$1" ]] ;
        then
            banner_warning "${1}"
        fi
    read -rp "Enter to continue, Cntrl-C to exit: "
}


reboot() {
    clr_bold clr_green " "
    clr_bold clr_green "Rebooting"
    "$(cmd "sudo")" shutdown -r now
}


is_package_installed() {
    # $1: package name
    local package_name=$1
    if [[ $(dpkg -l "${package_name}" 2> /dev/null | grep "${package_name}" | cut -f 1 -d " ") == "ii" ]]; then
        return 0
    else
        return 1
    fi
}


is_program_available() {
    # checkt ob ein programm verfügbar ist.
    # nicht für interne bash commands wie "ls"
    # $1: the program name to check
    local program_to_check="${1}"
    command -v "$program_to_check" >/dev/null 2>&1
}


install_package_if_not_present() {
    #$1: package
    #$2: silent  # will install silently when "True"
    local package silent
    package="${1}"
    silent="${2}"
    if ! is_package_installed "${package}"; then
        if [[ "${silent}" == "True" ]]; then
            retry_nofail "$(cmd "sudo")" apt-get install "${package}" -y  > /dev/null 2>&1
        else
            retry "$(cmd "sudo")" apt-get install "${package}" -y
        fi
    fi
    if ! is_package_installed "${package}"; then
       log_err "Installing ${package} failed"
       return 1
    fi
}


uninstall_package_if_present() {
    #$1: package
    #$2: silent  # will install silenty when "True"
    local package silent
    package="${1}"
    silent="${2}"

    if is_package_installed "${package}"; then
        if [[ "${silent}" == "True" ]]; then
            retry_nofail "$(cmd "sudo")" apt-get purge "${package}" -y > /dev/null 2>&1
        else
            retry "$(cmd "sudo")" apt-get purge "${package}" -y
        fi
    fi
    if is_package_installed "${package}"; then
       log_err "Uninstalling ${package} failed"
       return 1
    fi
}


backup_file() {
    # $1 : <file>
    # copies <file> to <file>.backup
    # copies <file> to <file>.original if <file>.original does not exist

    # if <file> exist
    local path_file="${1}"

    if [[ -f ${path_file} ]]; then
        local user group
        user=$(get_file_username "${path_file}")
        group=$(get_file_groupname "${path_file}")

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


get_prepend_auto_configuration_message_to_line() {
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


replace_or_add_lines_containing_string_in_file() {
    # $1 : File
    # $2 : search string
    # $3 : new line to replace
    # $4 : comment_char in that file
    local path_file search_string new_line comment_char user group number_of_lines_found

    path_file="${1}"
    search_string="${2}"
    new_line="${3}"
    comment_char="${4}"
    user=$(get_file_username "${path_file}")
    group=$(get_file_groupname "${path_file}")
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


is_hetzner_virtual_server() {
    if [[ $(grep -c "Hetzner_vServer" /sys/class/dmi/id/product_family) != "0" ]]; then
        return 0
    else
        return 1
    fi
}


call_function_from_commandline() {
    # $1+: arguments, where the first is the function name to call
    local call_args_array=("${@}")
    local function_name="${call_args_array[0]}"

    if [[ -n "${function_name}" ]]; then
        if is_bash_function_declared "${function_name}"; then
            # Call the function with the remaining arguments
            "${function_name}" "${call_args_array[@]:1}"
        else
            log_err "'${function_name}' is not a known function"
            exit 1
        fi
    else
        log_err "No function name provided"
        exit 1
    fi
}

beep() {
    echo -ne '\007'
}


lib_bash_split() {
    # $1 input
    # $2 separator ; the separator must not be <">
    # $3 index; - can be also -1 like in python
    if is_program_available python3; then
        local str_input="${1}"
        local str_separator="${2}"
        local num_index="${3}"
        echo "${str_input}" | python3 -c"import sys; sys.stdout.write(sys.stdin.read().split(\"${str_separator}\")[${num_index}])"
    else
        log_err "python3 needs to be installed in order to use the function lib_bash_split"
        exit 1
    fi
}


lib_bash_upper() {
    # $1 input
    local str_input="${1}"
    echo "${str_input^^}"
}


lib_bash_lower() {
    # $1 input
    local str_input="${1}"
    echo "${str_input,,}"
}


lib_bash_get_hostname_short() {
    local hostname_short
    hostname_short="$(hostname -s)"
    echo "${hostname_short}"
}


lib_bash_path_exist() {
    # $1 = Path to File or Directory
    local path_file="${1}"
    # shellcheck disable=SC2086
    if [[ -e "${path_file}" ]]; then
      return 0
    else
      return 1
    fi
}

is_sourced() {
    if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
        return 1
    else
        return 0
    fi
}

########################################################################################################################################################
# SELF-UPDATE CORE LOGIC
########################################################################################################################################################

_lib_bash_restart_parent() {
    # Get parent script path (the script that sourced lib_bash.sh)
    local parent_script=$(readlink -f "${BASH_SOURCE[-1]}")
    local script_args=("${@}")

    log "lib_bash: restarting parent script to apply updates"
    exec "$BASH" --noprofile --norc "$parent_script" "${script_args[@]}"
    exit 0
}

_user_is_allowed_to_update() {
    # Check if the user's UID matches the script's UID
    local script_uid=$(stat -c %u "$(_get_own_fullpath)")
    local current_uid=$(id -u)
    local script_user=$(getent passwd "$script_uid" | cut -d: -f1 || echo "Unknown user")
    local current_user=$(id -un)

    if [ "$script_uid" -ne "$current_uid" ]; then
        log_warn "lib_bash : can not apply updates, the current user '$current_user' \
                  (UID: $current_uid) is not the owner of the script (Owner: '$script_user', UID: $script_uid)"
        return 1
    else
        return 0
    fi
}

_lib_bash_self_update() {
    local script_dir="$(_get_own_dirname)"
    git config --global --add safe.directory /usr/local/lib_bash
    local current_hash=$(git -C "$script_dir" rev-parse HEAD 2>/dev/null)
    local remote_hash=$(git -C "$script_dir" ls-remote origin HEAD 2>/dev/null | awk '{print $1}')
    if [[ "$remote_hash" != "$current_hash" ]] && [[ -n "$remote_hash" ]]; then
        if ! _user_is_allowed_to_update; then return 2; fi  # Return 2 if update available but user not allowed
        log_wrench "lib_bash: new version available, updating..." "bold"
        git -C "$script_dir" fetch --all &> /dev/null
        git -C "$script_dir" reset --hard origin/main &> /dev/null
        git -C "$script_dir" reset --hard origin/master &> /dev/null
        git -C "$script_dir" clean -fd
        return 0
    fi
    return 1
}

help() {
  echo "to register the aliases and shortcuts issue following command:"
  echo "$(clr_green "sudo ./lib_bash.sh register") $(clr_yellow "# register aliases")"
  echo ""
  echo "after registering the shortcuts you can use following commands include the interactive shell."
  echo "update  # update linux"
  echo "lsdsk   # get a list of disk controllers and drives"
  echo "lsdisk  # get a list of disk controllers and drives"
  echo "install_latest_python # install latest python version"
  exit 0
}

register() {
  log "register"
  exit 0
}

test() {
  log "log"
  log_ok "log OK"
  log_wrench "log wrench"
  log_warn "log_warn"
  log_err "log_err"
  LIB_BASH_DEBUG_MODE="ON"
  log_debug "log_debug"
}


########################################################################################################################################################
# INITIALIZATION
########################################################################################################################################################

LIB_BASH_MAIN() {
    ! is_sourced || return 0  # Exit early if script is sourced
    (( $# )) || exit 0        # Terminate if no arguments provided
        case "$1" in
        # support --help command
        --help)
            help
            ;;
        *)
            # call any other function of lib_bash from the commandline
            call_function_from_commandline "${@}"
            ;;
    esac
}

_set_defaults

# Self-update and restart logic
if [[ -z "${LIB_BASH_RESTARTED-}" ]]; then  # Safe check for unset/nounset
    export LIB_BASH_RESTARTED=1
    if _lib_bash_self_update; then
        if is_sourced; then
            # Restart parent script when sourced
            _lib_bash_restart_parent "$@"
        else
            # Restart directly when executed
            exec "$BASH" --noprofile --norc "$0" "$@"
        fi
    fi
fi

LIB_BASH_MAIN "$@"
