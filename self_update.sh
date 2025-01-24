#!/bin/bash
# Self-update library
# 2025-01-24
##############################################################################
# USAGE
##############################################################################

# see : sample_self_update_main_script.sh

##############################################################################
# UPDATE MYSELF
##############################################################################

########################################################################################################################################################
# UPDATE MYSELF
########################################################################################################################################################
# 2025-01-23

# Add commit verification (placeholder - implement proper verification)
function verify_commit {
    local commit_hash=$1
    # Example placeholder - replace with actual verification
    if [[ -z "$commit_hash" ]]; then
        log_err "Invalid commit hash!"
        return 1
    fi
    return 0
}

function is_lib_bash_up_to_date {
    local git_remote_hash git_local_hash default_branch

    # Safely get default branch
    default_branch=$(git -C "${LIB_BASH_SELF_UPDATE_SELF_DIR}" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@') || {
        log_err "Failed to determine default branch - can not check platform self update"
        return 0
    }

    # Get remote hash
    git_remote_hash=$(git -C "${LIB_BASH_SELF_UPDATE_SELF_DIR}" ls-remote origin --heads "${default_branch}" | awk '{print $1}') || {
        log_err "Failed to get remote hash - can not check platform self update"
        return 0
    }

    # Get local hash
    git_local_hash=$(git -C "${LIB_BASH_SELF_UPDATE_SELF_DIR}" rev-parse HEAD) || {
        log_warn "Failed to get local hash - can not check platform self update"
        return 0
    }

    [[ "${git_remote_hash}" == "${git_local_hash}" ]] && return 0
    return 1
}

function lib_bash_update_myself {
    local default_branch
    (
        set -eo pipefail
        cd "${LIB_BASH_SELF_UPDATE_SELF_DIR}" || exit 99

        # Get default branch
        default_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@') || exit 100

        # Fetch updates
        git fetch --all || exit 101

        # Verify commit
        verify_commit "origin/${default_branch}" || exit 102

        # Reset to latest
        git reset --hard "origin/${default_branch}" || exit 103
    )
    return $?
}

#######################################
# Validate file ownership for self-update
# Globals: #
#   None
# Arguments:
#   $1: file path to check
# Returns:
#   0 - ownership matches
#   1 - ownership mismatch
#   2 - file not found
#   3 - stat command failed
# Outputs:
#   Warning messages on ownership mismatch
#######################################
function check_self_update_ownership {
    local file="$1"
    local current_uid file_uid file_owner

    # Verify file existence
    if [[ ! -e "$file" ]]; then
        log_warn "File not found: '${file}'"
        return 2
    fi

    # Get current user's UID
    current_uid=$(id -u) || return 3

    # Cross-platform UID/username retrieval
    if ! file_uid=$(stat -c '%u' "$file" 2>/dev/null) && \
       ! file_uid=$(stat -f '%u' "$file" 2>/dev/null); then
        log_warn "Failed to get UID for: '${file}'"
        return 3
    fi

    if ! file_owner=$(stat -c '%U' "$file" 2>/dev/null) && \
       ! file_owner=$(stat -f '%Su' "$file" 2>/dev/null); then
        log_warn "Failed to get owner for: '${file}'"
        return 3
    fi

    # Ownership validation
    if (( file_uid != current_uid )); then
        log_warn "Cannot self-update: File '${file}' owned by '${file_owner}' (UID:${file_uid}), current UID:${current_uid}"
        return 1
    fi

    return 0
}

#######################################
# Validate required dependencies for self-update
# Globals:
#   LIB_BASH_SELF_UPDATE_SELF
#   LIB_BASH_SELF_UPDATE_SELF_MAIN_FUNCTION
# Arguments:
#   None
# Returns:
#   0 - all dependencies met
#   1 - missing dependencies
#######################################
function _validate_self_update_dependencies {
    # Check required variables
    local missing_vars=()
    [[ -z "${LIB_BASH_SELF_UPDATE_SELF}" ]] && missing_vars+=("LIB_BASH_SELF_UPDATE_SELF")
    [[ -z "${LIB_BASH_SELF_UPDATE_SELF_MAIN_FUNCTION}" ]] && missing_vars+=("LIB_BASH_SELF_UPDATE_SELF_MAIN_FUNCTION")

    if (( ${#missing_vars[@]} > 0 )); then
        log_err "Missing required variables: ${missing_vars[*]}"
        return 1
    fi

    # Check main function existence
    if ! declare -F "${LIB_BASH_SELF_UPDATE_SELF_MAIN_FUNCTION}" >/dev/null; then
        log_err "Main function not found: ${LIB_BASH_SELF_UPDATE_SELF_MAIN_FUNCTION}"
        return 1
    fi

    return 0
}

#######################################
# Perform self-update if needed
# Globals:
#   LIB_BASH_SELF_UPDATE_SELF
#   BASH
# Arguments:
#   All arguments passed to the script
# Returns:
#   Exits script on successful update
#   Returns error code on failure
#######################################
function lib_bash_self_update {
    if ! is_lib_bash_up_to_date; then
        log "Update available! Performing self-update..."

        # Validate dependencies
        _validate_self_update_dependencies || return $?

        # Verify file ownership
        check_self_update_ownership "${LIB_BASH_SELF_UPDATE_SELF}" || return $?

        # Perform update

        if lib_bash_update_myself; then
            log "Successfully updated! Restarting..."

            # Clean restart with updated script
            exec "${BASH}" --noprofile --norc -c \
                "source '${LIB_BASH_SELF_UPDATE_SELF}' && \
                '${LIB_BASH_SELF_UPDATE_SELF_MAIN_FUNCTION}' \"\$@\"" \
                _ "$@"
        else
            local update_status=$?
            log_err "Update failed with error code: ${update_status}"
            return ${update_status}
        fi
    fi
}


if ! declare -F "source_lib_bash_dependencies" >/dev/null 2>&1
then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_bash.sh"
fi
