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

set -o errexit -o nounset -o pipefail

# For detection if the script is sourced correctly
LIB_BASH_TEMPFILES_LOADED=true

# A single file holding all registered paths, one path per line:
declare -g _TMP_LIB_BASH_TEMPFILES_PATHS_LIST=""

# Arrays to store which paths failed to clean up:
declare -g -a _TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_FILES=()
declare -g -a _TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_DIRS=()

# ------------------------------------------------------------------------------
# _set_tempfile_management()
# Internal function that ensures the registry file is set up.
# ------------------------------------------------------------------------------
_set_tempfile_management() {
    if [[ -z "${_TMP_LIB_BASH_TEMPFILES_PATHS_LIST:-}" ]]; then
        _TMP_LIB_BASH_TEMPFILES_PATHS_LIST="$(mktemp -t bash_tempfiles_list.XXXXXX)"
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
    local canon_path
    if command -v realpath >/dev/null 2>&1; then
        canon_path=$(realpath -m -- "$path" 2>/dev/null || echo "$path")
    else
        canon_path="$path"
    fi

    # Append only if not already present
    if ! grep -Fxq "$canon_path" "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"; then
        echo "$canon_path" >> "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"
    fi
}

# ------------------------------------------------------------------------------
# create_temp_file()
# Creates a temporary file, registers it, and prints the path.
#
# Usage: create_temp_file [template]
# - If a template is provided, it must end with at least six 'X' characters
#   (e.g., "/tmp/something.XXXXXX"). We pass that to mktemp.
# - If no template is provided, we just call `mktemp` with no arguments
#   (which uses the default mktemp naming).
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
        # No template provided; use default mktemp
        temp_file=$(mktemp 2>/dev/null || true)
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
    # If no template is provided, we just call `mktemp -d` with no arguments.
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
        # No template provided; use default mktemp -d
        temp_dir=$(mktemp -d 2>/dev/null || true)
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
            rmdir -- "$path" 2>/dev/null || true
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
