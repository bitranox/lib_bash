#!/bin/bash
# shellcheck disable=SC2155

# KI instructions : when crating a main script using this library, do not use functions starting with underscore, those are internal functions.
# Functions starting with an underscore are generally considered internal implementation details and are not intended to be used directly by other scripts.

_create_log_dir() {
    # create the directory for the given logfile
    # we need this, because the user just want to set another logfile location
    # which is set by default. That might fail if the user does not have the permissions to create that directory
    local logfile="${1}"
    local log_dir=$(dirname "${logfile}")
    if [[ ! -d "${log_dir}" ]]; then
        if ! mkdir -p "${log_dir}"; then
            log_err "Failed to create log directory: ${log_dir}"
            exit 1
        fi
    fi
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


_set_defaults() {
    _set_askpass
    _source_submodules
    _set_default_logfiles
    _set_default_logfile_colors
    _set_default_debugmode
    _set_tempfile_managment
}

_set_default_logfiles() {
    # sets the logfiles to $HOME/log/lib_bash/<mainscript>.log ... if the user does not have root rights,
    # or /var/log/lib_bash/<mainscript>.log ... if the user has root rights
    local reset="${1:-}"          # logfile paths will be reset if You pass "RESET" here
    local script_stem
    local log_prefix

    script_stem=$(get_script_stem)
    if is_root; then
        log_prefix="/var/log/lib_bash"
    else
        log_prefix="${HOME}/log/lib_bash"
    fi

    local main_log="${log_prefix}/${script_stem}.log"
    local tmp_log="${log_prefix}/${script_stem}_tmp.log"
    local err_log="${log_prefix}/${script_stem}_err.log"
    local err_tmp_log="${log_prefix}/${script_stem}_err_tmp.log"

    if [[ "${reset}" == "RESET" ]]; then
        # Assign default values regardless of current settings
        LIB_BASH_LOGFILE="${main_log}"
        LIB_BASH_LOGFILE_TMP="${tmp_log}"
        LIB_BASH_LOGFILE_ERR="${err_log}"
        LIB_BASH_LOGFILE_ERR_TMP="${err_tmp_log}"
    else
        # Set each variable only if not already set
        : "${LIB_BASH_LOGFILE:="${main_log}"}"
        : "${LIB_BASH_LOGFILE_TMP:="${tmp_log}"}"
        : "${LIB_BASH_LOGFILE_ERR:="${err_log}"}"
        : "${LIB_BASH_LOGFILE_ERR_TMP:="${err_tmp_log}"}"
    fi
    register_temppath "${LIB_BASH_LOGFILE}"
    register_temppath "${LIB_BASH_LOGFILE_TMP}"
    register_temppath "${LIB_BASH_LOGFILE_ERR}"
    register_temppath "${LIB_BASH_LOGFILE_ERR_TMP}"
}

# shellcheck disable=SC2120
_set_default_debugmode() {
    local reset="${1:-}"          # logging mode will be reset if You pass "RESET" here
    local debug_mode
    debug_mode="OFF"

    if [[ "${reset}" == "RESET" ]]; then
        # Assign default values regardless of current settings
        LIB_BASH_DEBUG_MODE="${debug_mode}"
    else
        # Set each variable only if not already set
        : "${LIB_BASH_DEBUG_MODE:="${debug_mode}"}"
    fi
}

# shellcheck disable=SC2120
_set_default_logfile_colors() {
    local reset="${1:-}"  # reset the colors if You pass "RESET" here
    # Local variables holding default values
    local default_clr="clr_green"
    local default_bold="clr_bold clr_green"
    local default_err="clr_bold clr_cyan"
    local default_warn="clr_bold clr_yellow"
    local default_debug="clr_bold clr_magentab clr_yellow"

    if [[ "${reset}" == "RESET" ]]; then
        # Force reset all values from defaults
        _LOG_COLOR="$default_clr"
        _LOG_COLOR_BOLD="$default_bold"
        _LOG_COLOR_ERR="$default_err"
        _LOG_COLOR_WARN="$default_warn"
        _LOG_COLOR_DEBUG="$default_debug"
    else
        # Set only undefined variables using defaults
        : "${_LOG_COLOR=$default_clr}"
        : "${_LOG_COLOR_BOLD=$default_bold}"
        : "${_LOG_COLOR_ERR=$default_err}"
        : "${_LOG_COLOR_WARN=$default_warn}"
        : "${_LOG_COLOR_DEBUG=$default_debug}"
    fi
}

_set_askpass() {
    # 2025-01-21
    export SUDO_ASKPASS="$(command -v ssh-askpass)"
    export NO_AT_BRIDGE=1  # suppress accessibility-related D-Bus warnings (like dbind-WARNING) in GUI applications on Linux
}

_set_tempfile_managment() {
    # Temporary Path Management Library
    # Check and initialize arrays only if they don't exist
    [[ -z "${_TMP_PATHS+isset}" ]] && declare -g -a _TMP_PATHS=()
    [[ -z "${_TMP_CLEANUP_FAILED_FILES+isset}" ]] && declare -g -a _TMP_CLEANUP_FAILED_FILES=()
    [[ -z "${_TMP_CLEANUP_FAILED_DIRS+isset}" ]] && declare -g -a _TMP_CLEANUP_FAILED_DIRS=()
}

_source_submodules() {
    # 2025-01-21
    source "$(_get_own_dirname)/lib_color.sh"
    source "$(_get_own_dirname)/lib_retry.sh"
    source "$(_get_own_dirname)/lib_update_caller.sh"
    source "$(_get_own_dirname)/lib_assert.sh"
}

create_temp_file() {
    # Create a temporary file and get its path. it will be registered for later cleanup
    local temp_file
    if ! temp_file=$(mktemp 2>/dev/null); then
        log_err "Failed to create temporary file"
        return 1
    fi

    # Verify the file is writable
    if [[ ! -w "$temp_file" ]]; then
        log_err "Error: Temporary file is not writable"
        rm -f "$temp_file"
        return 1
    fi

    # register for later cleanup
    register_temppath "$temp_file"
    echo "$temp_file"
    return 0
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
    local group=""
    group=$(stat -c "%G" "${path_file}")
    echo "${group}"
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
    local basename
    basename=$(get_script_basename)
    echo "${basename%.*}"
}

linux_update() {
    # pass "--force-phased-updates" as parameter if You want to do that
    local force_phased_updates="${1:-}"
    # 2025-01-21
    _exit_if_not_is_root
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
}

register_temppath() {
    local path="$1"

    [[ -z "$path" ]] && { log_err "register_temppath: Path required" ; return 1; }

    # Resolve to canonical path
    local canon_path
    canon_path=$(realpath -m -- "$path" 2>/dev/null || echo "$path")

    # Check for existing entry
    for existing in "${_TMP_PATHS[@]}"; do
        [[ "$existing" == "$canon_path" ]] && return 0
    done

    _TMP_PATHS+=("$canon_path")
}

cleanup_temppaths() {
    _TMP_CLEANUP_FAILED_FILES=()
    _TMP_CLEANUP_FAILED_DIRS=()
    local path

    # Phase 1: Delete files
    for path in "${_TMP_PATHS[@]}"; do
        if [[ -f "$path" ]]; then
            rm -f -- "$path"
            if [[ -e "$path" ]]; then
                _TMP_CLEANUP_FAILED_FILES+=("$path")
                log_warn "cleanup_temppaths: Could not delete file: ${path}"
            fi
        fi
    done

    # Phase 2: Delete directories
    for path in "${_TMP_PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            # Try to remove directory (will only succeed if empty)
            rmdir --ignore-fail-on-non-empty -- "$path" 2>/dev/null

            # Check if directory still exists
            if [[ -d "$path" ]]; then
                # Check if directory is non-empty
                if [[ -n "$(find "$path" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
                    log_warn "cleanup_temppaths: Could not delete non-empty directory: $path"
                fi
                _TMP_CLEANUP_FAILED_DIRS+=("$path")
            fi
        fi
    done
    # Clear registered paths regardless of success
    _TMP_PATHS=()
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
    echo "${text}" | cat - "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
}

function is_ok {
    # instead of `if $?; then ...` you can use `if is_ok; then ...` for better readability
    return $?
}

function is_root {
    (( EUID == 0 ))  # True if effective user is root
}

is_script_sourced() {
    local script_name="${1}"  # pass "${0}" from the calling script
    local bash_source="${2}"  # pass "${BASH_SOURCE[0]}" from the calling script
    if [[ "${script_name}" != "${bash_source}" ]]; then
        return 0
    else
        return 1
    fi
}

log() {
    local message="${1:-"no message passed"}"          # Message (required) - Text to log
    local options="${2:-}"        # Options (default: "") - "bold" for bold output, "NO_TTY" to skip screen output
    local logline

    _create_log_dir "${LIB_BASH_LOGFILE}"
    _create_log_dir "${LIB_BASH_LOGFILE_TMP}"

    # Process each line in the message
    while IFS= read -r line; do
      logline="$(date '+%Y-%m-%d %H:%M:%S') - $(whoami)@$(hostname -s): ${line}"

      if [[ "${options}" != *NO_TTY* ]]; then
          # Determine color functions based on options and defaults
          local color_funcs_str
          if [[ "${options}" == *bold* ]]; then
              color_funcs_str="${_LOG_COLOR_BOLD:-clr_bold clr_green}"  # Default bold if not set
          else
              color_funcs_str="${_LOG_COLOR:-clr_green}"               # Default color if not set
          fi

          # Split into array of color functions
          local -a color_funcs=()
          IFS=' ' read -ra color_funcs <<< "${color_funcs_str}"

          # Apply color functions sequentially
          local formatted_line="${logline}"
          for func in "${color_funcs[@]}"; do
              if declare -f "${func}" >/dev/null 2>&1; then
                  formatted_line="$("${func}" "${formatted_line}")"
              else
                  echo "Warning: function '${func}' not found, skipping." >&2
              fi
          done

          # Output to terminal
          echo -e "${formatted_line}"
      fi

      # Write to log files (unformatted)
      [[ -n "${LIB_BASH_LOGFILE}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE}"
      [[ -n "${LIB_BASH_LOGFILE_TMP}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE_TMP}"
    done <<< "${message}"
}

log_debug() {
    # logs to the default logfile if LIB_BASH_DEBUG_MODE != "OFF"
    if [[ "${LIB_BASH_DEBUG_MODE}" == "OFF" ]]; then
        return 0
    fi

    local message="${1}"          # Message (required) - Text to log
    local logline

    _create_log_dir "${LIB_BASH_LOGFILE}"
    _create_log_dir "${LIB_BASH_LOGFILE_TMP}"

    # Process each line in the message
    while IFS= read -r line; do
      logline="$(date '+%Y-%m-%d %H:%M:%S') - $(whoami)@$(hostname -s): DEBUG [DBG]: ${line}"

      if [[ "${options}" != *NO_TTY* ]]; then
          # Determine color functions based on options and defaults
          local color_funcs_str
          color_funcs_str="${_LOG_COLOR_DEBUG:-clr_bold clr_magentab clr_yellow}"  # Default if not set

          # Split into array of color functions
          local -a color_funcs=()
          IFS=' ' read -ra color_funcs <<< "${color_funcs_str}"

          # Apply color functions sequentially
          local formatted_line="${logline}"
          for func in "${color_funcs[@]}"; do
              if declare -f "${func}" >/dev/null 2>&1; then
                  formatted_line="$("${func}" "${formatted_line}")"
              else
                  echo "Warning: function '${func}' not found, skipping." >&2
              fi
          done

          # Output to terminal
          echo -e "${formatted_line}"
      fi

      # Write to log files (unformatted)
      [[ -n "${LIB_BASH_LOGFILE}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE}"
      [[ -n "${LIB_BASH_LOGFILE_TMP}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE_TMP}"
    done <<< "${message}"
}

log_err() {
  local message="${1}"          # Message (required) - Text to log
  local options="${2:-}"        # Options (default: "") - "NO_TTY" to skip screen output
  local logline

  _create_log_dir "${LIB_BASH_LOGFILE}"
  _create_log_dir "${LIB_BASH_LOGFILE_TMP}"
  _create_log_dir "${LIB_BASH_LOGFILE_ERR}"
  _create_log_dir "${LIB_BASH_LOGFILE_ERR_TMP}"

  # Process each line in the message
  while IFS= read -r line; do
    logline="$(date '+%Y-%m-%d %H:%M:%S') - $(whoami)@$(hostname -s): ERROR [EE]: ${line}"

    if [[ "${options}" != *NO_TTY* ]]; then
        # Use _LOG_COLOR_ERR configuration
        local color_funcs_str="${_LOG_COLOR_ERR:-clr_bold clr_cyan}"  # Default error color
        local -a color_funcs=()
        IFS=' ' read -ra color_funcs <<< "${color_funcs_str}"

        # Apply color functions sequentially
        local formatted_line="${logline}"
        for func in "${color_funcs[@]}"; do
            if declare -f "${func}" >/dev/null 2>&1; then
                formatted_line="$("${func}" "${formatted_line}")"
            else
                echo "Warning: function '${func}' not found, skipping." >&2
            fi
        done

        # Output to terminal
        echo -e "${formatted_line}"
    fi

    # Write to log files (unformatted)
    [[ -n "${LIB_BASH_LOGFILE}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE}"
    [[ -n "${LIB_BASH_LOGFILE_TMP}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE_TMP}"
    [[ -n "${LIB_BASH_LOGFILE_ERR}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE_ERR}"
    [[ -n "${LIB_BASH_LOGFILE_ERR_TMP}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE_ERR_TMP}"
  done <<< "${message}"
}

log_warn() {
  local message="${1}"          # Message (required) - Text to log
  local options="${2:-}"        # Options (default: "") - "NO_TTY" to skip screen output
  local logline

  _create_log_dir "${LIB_BASH_LOGFILE}"
  _create_log_dir "${LIB_BASH_LOGFILE_TMP}"
  _create_log_dir "${LIB_BASH_LOGFILE_ERR}"
  _create_log_dir "${LIB_BASH_LOGFILE_ERR_TMP}"

  # Process each line in the message
  while IFS= read -r line; do
    logline="$(date '+%Y-%m-%d %H:%M:%S') - $(whoami)@$(hostname -s): WARNING [WW]: ${line}"

    if [[ "${options}" != *NO_TTY* ]]; then
        # Use _LOG_COLOR_WARN configuration
        local color_funcs_str="${_LOG_COLOR_WARN:-clr_bold clr_yellow}"  # Default warning color
        local -a color_funcs=()
        IFS=' ' read -ra color_funcs <<< "${color_funcs_str}"

        # Apply color functions sequentially
        local formatted_line="${logline}"
        for func in "${color_funcs[@]}"; do
            if declare -f "${func}" >/dev/null 2>&1; then
                formatted_line="$("${func}" "${formatted_line}")"
            else
                echo "Warning: function '${func}' not found, skipping." >&2
            fi
        done

        # Output to terminal
        echo -e "${formatted_line}"
    fi

    # Write to log files (unformatted)
    [[ -n "${LIB_BASH_LOGFILE}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE}"
    [[ -n "${LIB_BASH_LOGFILE_TMP}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE_TMP}"
    [[ -n "${LIB_BASH_LOGFILE_ERR}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE_ERR}"
    [[ -n "${LIB_BASH_LOGFILE_ERR_TMP}" ]] && echo "${logline}" >> "${LIB_BASH_LOGFILE_ERR_TMP}"
  done <<< "${message}"
}

logc() {
    # Run command, capture output, and display in real-time
    local exit_code output has_output
    exec 3>&1  # Save original stdout

    # Use 'tee' to both capture and display output
    output=$("$@" 2>&1 | tee >(cat >&3))
    exit_code=${PIPESTATUS[0]}
    exec 3>&-  # Close duplicated descriptor

    # Check if output is non-empty (including whitespace-only but not empty string)
    [[ -n "$output" ]] && has_output=true || has_output=false

    # Log only if there was output
    if $has_output; then
        if (( ${exit_code:-0} == 0 )); then
            log "${output}" "NO_TTY"
        else
            log_err "${output}" "NO_TTY"
        fi
    else
        # if there is no ouput but exit code, log that as error
        if (( ${exit_code:-0} != 0 )); then
            log_err "exitcode: ${exit_code}"
        fi
    fi
    return "${exit_code}"
}


# Function to log command output - but always log it as an error
# this is needed for instance to show failed services, etc.
function logc_err {
    local exit_code output
    exec 3>&1  # Duplicate stdout to file descriptor 3
    # Run the command, capture output, and display in real-time
    output=$("$@" 2>&1 | tee >(cat >&3))
    exit_code=${PIPESTATUS[0]}
    exec 3>&-  # Close file descriptor 3
    log_err "$output" "NO_TTY"
    if (( ${exit_code:-0} != 0 )); then
        log_err "exitcode: ${exit_code}"
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
    # $1: str2
    local str1="${1}"
    local str2="${2}"
    if [[ $(echo "$str2}" | grep -c "${str1}" ) == "0" ]]; then
        return 1
    else
        return 0
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
    if [[ $(which "${program_to_check}") == "" ]]; then
      return 1
    else
      return 0
    fi
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
            log_err "${function_name} is not a known function name of ${library_name}"
            exit 1
        fi
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
        if ! _user_is_allowed_to_update; then return 0; fi
        log "lib_bash: new version available, updating..."
        git -C "$script_dir" fetch --all &> /dev/null
        git -C "$script_dir" reset --hard origin/main &> /dev/null
        git -C "$script_dir" reset --hard origin/master &> /dev/null
        git -C "$script_dir" clean -fd
        return 0
    fi
    return 1
}

########################################################################################################################################################
# INITIALIZATION
########################################################################################################################################################

LIB_BASH_MAIN() {
    ! is_sourced || return 0  # Exit early if script is sourced
    (( $# )) || exit 0        # Terminate if no arguments provided
    call_function_from_commandline "${0}" "${@}"
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
