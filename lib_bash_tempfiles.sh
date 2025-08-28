#!/bin/bash
# shellcheck disable=SC2155,SC2034
# lib_bash_tempfiles.sh

# **Description:**
# This script provides a library for managing temporary paths (files or directories)
# in Bash by storing all registered paths in a single text file, one path per line.
#
# Key features:
#   - A single registry file (paths list) to store all registered paths.
#   - register_temppath: Adds a path to the registry, avoiding duplicates.
#   - create_temp_file, create_temp_dir: Creates a file/dir via mktemp, registers it,
#       and prints the path.
#       - create_temp_file can optionally accept a template that must end
#         with at least six 'X' characters (e.g. "/tmp/myfile.XXXXXX").
#   - cleanup_temppaths: Cleans up all registered paths in two passes:
#       1) Remove all files.
#       2) Remove all empty directories.
#     Logs warnings if something cannot be removed, and records them in
#       _TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_FILES or
#       _TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_DIRS.
#   - _get_number_of_registered_paths: Returns the current number of lines (entries)
#     in the registry file (i.e., how many paths are registered).

# For detection if the script is sourced correctly
LIB_BASH_TEMPFILES_LOADED=true

# Strict mode for safer bash scripting
_lib_bash_tempfiles_is_in_script_mode() {
  case "${BASH_SOURCE[0]}" in
    "${0}") return 0 ;;  # script mode
    *)      return 1 ;;
  esac
}

# --- only in script mode ---
if _lib_bash_tempfiles_is_in_script_mode; then
  # Strict mode & traps only when run directly
  set -Eeuo pipefail
  IFS=$'\n\t'
  umask 022
  # shellcheck disable=SC2154
  trap 'ec=$?; echo "ERR $ec at ${BASH_SOURCE[0]}:${LINENO}: ${BASH_COMMAND}" >&2' ERR
fi


# A single file holding all registered paths, one path per line:
_TMP_LIB_BASH_TEMPFILES_PATHS_LIST=""

# Arrays to store which paths failed to clean up:
_TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_FILES=()
_TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_DIRS=()

# ------------------------------------------------------------------------------
# _set_tempfile_management()
# Internal function that ensures the registry file is set up.
# ------------------------------------------------------------------------------
_set_tempfile_management() {
    if [[ -z "${_TMP_LIB_BASH_TEMPFILES_PATHS_LIST:-}" ]]; then
        _TMP_LIB_BASH_TEMPFILES_PATHS_LIST="$(mktemp "${TMPDIR:-/tmp}/bash_tempfiles_list.XXXXXXXX")"
    fi

    # Make sure the file exists
    # shellcheck disable=SC2188
    [[ -f "${_TMP_LIB_BASH_TEMPFILES_PATHS_LIST:-}" ]] || > "${_TMP_LIB_BASH_TEMPFILES_PATHS_LIST:-}"
}

# Call init function immediately
_set_tempfile_management

# ------------------------------------------------------------------------------
# Logging Helpers
# only define those helpers if not already defined by lib_bash_log
# ------------------------------------------------------------------------------
if ! declare -f log_err >/dev/null 2>&1; then
    log_err() {
        printf "%s: Error: %s\n" "$(basename "$0")" "$*" >&2
    }
fi

if ! declare -f log_warn >/dev/null 2>&1; then
    log_warn() {
        printf "%s: Warning: %s\n" "$(basename "$0")" "$*" >&2
    }
fi

# ------------------------------------------------------------------------------
# _get_number_of_registered_paths()
# Returns (via stdout) how many lines are currently in the registry file,
# i.e. how many paths have been registered. This does NOT verify whether
# they exist on disk or are files/directories—just how many lines in the file.
# ------------------------------------------------------------------------------
_get_number_of_registered_paths() {
    if [[ -s "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST" ]]; then
        wc -l < "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"
    else
        echo 0
    fi
}

# ------------------------------------------------------------------------------
# register_temppath()
# Registers a given path (file or directory) by adding it to the single
# registry file, deduplicating by line.
# ------------------------------------------------------------------------------
register_temppath() {
    local path="$1"
    [[ -z "$path" ]] && { log_err "register_temppath: Path required."; return 1; }

    _set_tempfile_management

    # Attempt to resolve canonical path if realpath is available
    local canon_path="$path"
    if command -v realpath >/dev/null 2>&1; then
        if realpath -m / >/dev/null 2>&1; then
            canon_path=$(realpath -m -- "$path" 2>/dev/null || echo "$path")
        else
            canon_path=$(realpath -- "$path" 2>/dev/null || echo "$path")
        fi
    elif command -v readlink >/dev/null 2>&1; then
        canon_path=$(readlink -f -- "$path" 2>/dev/null || echo "$path")
    fi

    # Append only if not already present
    if ! grep -Fxq "$canon_path" "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"; then
        echo "$canon_path" >> "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"
    fi
}

# ------------------------------------------------------------------------------
# print_temppath_registry()
# Prints the absolute path to the registry file holding all registered paths.
# ------------------------------------------------------------------------------
print_temppath_registry() {
    _set_tempfile_management
    echo "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"
}

# ------------------------------------------------------------------------------
# list_temppaths()
# Prints all currently registered paths (one per line) from the registry file.
# Does not check for existence; mirrors registry contents.
# ------------------------------------------------------------------------------
list_temppaths() {
    _set_tempfile_management
    # Print without additional formatting; empty output if no entries
    cat -- "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST" 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# unregister_temppath()
# Removes a given path (file or directory) from the registry file, if present.
# Returns 0 if the entry was found and removed, 1 if not found, >1 on errors.
# ------------------------------------------------------------------------------
unregister_temppath() {
    local path="$1"
    [[ -z "$path" ]] && { log_err "unregister_temppath: Path required."; return 1; }

    _set_tempfile_management

    # Canonicalize in the same spirit as register_temppath
    local canon_path="$path"
    if command -v realpath >/dev/null 2>&1; then
        if realpath -m / >/dev/null 2>&1; then
            canon_path=$(realpath -m -- "$path" 2>/dev/null || echo "$path")
        else
            canon_path=$(realpath -- "$path" 2>/dev/null || echo "$path")
        fi
    elif command -v readlink >/dev/null 2>&1; then
        canon_path=$(readlink -f -- "$path" 2>/dev/null || echo "$path")
    fi

    # Create a temporary file in the same directory when possible
    local reg_dir tmpfile rc
    reg_dir="${_TMP_LIB_BASH_TEMPFILES_PATHS_LIST%/*}"
    tmpfile=$(mktemp "$reg_dir/.tmp.XXXXXXXX" 2>/dev/null || mktemp "${TMPDIR:-/tmp}/.tmp.XXXXXXXX")

    # Filter out the exact matching line; set rc=0 if removed, rc=1 if not found
    if awk -v target="$canon_path" '{ if ($0 != target) print $0; else found=1 } END { exit (found?0:1) }' \
        "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST" > "$tmpfile" 2>/dev/null; then
        rc=0
    else
        rc=1
    fi

    # Replace the registry with the filtered version
    if ! mv -f -- "$tmpfile" "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"; then
        log_err "unregister_temppath: Failed to update registry file"
        rm -f -- "$tmpfile" 2>/dev/null || true
        return 2
    fi

    return "$rc"
}

# ------------------------------------------------------------------------------
# clear_temppath_registry()
# Truncates the registry file, effectively removing all registered paths while
# keeping the registry file itself in place.
# ------------------------------------------------------------------------------
clear_temppath_registry() {
    _set_tempfile_management
    : > "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"
}

# ------------------------------------------------------------------------------
# create_temp_file()
# Creates a temporary file, registers it, and prints the path.
#
# Usage: create_temp_file [template]
# - If a template is provided, it must end with at least six 'X' characters
#   (e.g., "/tmp/something.XXXXXX"). We pass that to mktemp.
# - If no template is provided, we use a portable default
#   template under `${TMPDIR:-/tmp}`.
# ------------------------------------------------------------------------------
create_temp_file() {
    local template="${1:-}"  # optional argument
    local temp_file=""

    if [[ -n "$template" ]]; then
        # Ensure the template ends with at least six consecutive X's
        if [[ ! "$template" =~ X{6,}$ ]]; then
            log_err "Template must end with at least six consecutive X characters: $template"
            return 1
        fi

        # Attempt mktemp with the given template
        temp_file=$(mktemp "$template" 2>/dev/null || true)
    else
        # No template provided; use portable default mktemp template
        temp_file=$(mktemp "${TMPDIR:-/tmp}/tmpfile.XXXXXXXX" 2>/dev/null || true)
    fi

    if [[ -z "$temp_file" ]]; then
        log_err "Failed to create temporary file"
        return 1
    fi

    if [[ ! -w "$temp_file" ]]; then
        log_err "Temporary file is not writable: $temp_file"
        rm -f "$temp_file"
        return 1
    fi

    # Register the file
    register_temppath "$temp_file"

    # Print the path so caller can capture it
    echo "$temp_file"
}

create_temp_dir() {
    # Usage: create_temp_dir [template]
    #
    # If a template is provided, it must end with at least six consecutive 'X'
    # characters (e.g., "/tmp/something.XXXXXX") for mktemp -d to work reliably.
    # If no template is provided, we use a portable default
    # template under `${TMPDIR:-/tmp}`.
    #
    # Registers the created directory path for later cleanup, and prints the path
    # to stdout.

    local template="${1:-}"  # optional argument
    local temp_dir=""

    if [[ -n "$template" ]]; then
        # Ensure the template ends with at least six consecutive X's
        if [[ ! "$template" =~ X{6,}$ ]]; then
            log_err "Template must end with at least six consecutive X characters: $template"
            return 1
        fi

        # Attempt mktemp -d with the given template
        temp_dir=$(mktemp -d "$template" 2>/dev/null || true)
    else
        # No template provided; use portable default mktemp -d template
        temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/tmpdir.XXXXXXXX" 2>/dev/null || true)
    fi

    if [[ -z "$temp_dir" ]]; then
        log_err "Failed to create temporary directory"
        return 1
    fi

    if [[ ! -w "$temp_dir" ]]; then
        log_err "Temporary directory is not writable: $temp_dir"
        rm -rf "$temp_dir"
        return 1
    fi

    # Register the directory
    register_temppath "$temp_dir"

    # Print the path so the caller can capture it
    echo "$temp_dir"
}


# ------------------------------------------------------------------------------
# cleanup_temppaths()
# Cleans up all registered paths in two passes:
#   1) Remove all files
#   2) Remove all directories (rmdir only removes empty dirs)
# Logs warnings if removal fails, and stores failed paths in:
#   _TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_FILES or
#   _TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_DIRS.
# Finally, clears the registry file. Returns 0 if all removed, 1 if any fail.
# ------------------------------------------------------------------------------
cleanup_temppaths() {
    _set_tempfile_management

    _TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_FILES=()
    _TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_DIRS=()

    if [[ ! -f "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST" ]]; then
        # Nothing to clean
        return 0
    fi

    # Pass 1: Remove all files
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        if [[ -f "$path" ]]; then
            rm -f -- "$path" 2>/dev/null
            if [[ -e "$path" ]]; then
                _TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_FILES+=("$path")
                log_warn "cleanup_temppaths: Could not delete file: $path"
            fi
        fi
    done < "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"

    # Pass 2: Remove all (empty) directories
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        if [[ -d "$path" ]]; then
            rmdir "$path" 2>/dev/null || true
            if [[ -d "$path" ]]; then
                # Directory still exists (non-empty or permission issue)
                if [[ -n "$(find "$path" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
                    log_warn "cleanup_temppaths: Could not delete non-empty directory: $path"
                fi
                _TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_DIRS+=("$path")
            fi
        fi
    done < "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"

    # Clear the registry file
    : > "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"

    # Return 1 if any failures
    if [[ ${#_TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_FILES[@]} -gt 0 ]] \
       || [[ ${#_TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_DIRS[@]} -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Final check to ensure everything is initialized
_set_tempfile_management
