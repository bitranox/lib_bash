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
        log_err "Failed to determine default branch"
        return 2
    }

    # Get remote hash
    git_remote_hash=$(git -C "${LIB_BASH_SELF_UPDATE_SELF_DIR}" ls-remote origin --heads "${default_branch}" | awk '{print $1}') || {
        log_err "Failed to get remote hash"
        return 3
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

function check_self_update_ownership {
    # Validate that the specified file is owned by the current user
    # Usage: check_self_update_ownership "/path/to/file"
    # Returns: 0 if ownership matches, 1 if not

    local file="$1"
    local current_uid
    local file_uid
    local file_owner

    # Get current user's UID
    current_uid=$(id -u)

    # Get file's UID (cross-platform)
    file_uid=$(stat -c '%u' "$file" 2>/dev/null || stat -f '%u' "$file" 2>/dev/null)

    # Get file owner's username (cross-platform)
    file_owner=$(stat -c '%U' "$file" 2>/dev/null || stat -f '%Su' "$file" 2>/dev/null)

    # Compare UIDs for ownership check
    if [ "$file_uid" -ne "$current_uid" ]; then
        log_warn "Cannot self_update: The file '${file}' is owned by '${file_owner}' (UID: ${file_uid}), not your account (UID: ${current_uid})"
        return 1
    fi

    return 0
}


function lib_bash_self_update {
        if ! is_lib_bash_up_to_date; then
            log "Update available! Performing self-update..."
            # Dependency check (ensure these are defined in the main script)
            if [[ -z "${LIB_BASH_SELF_UPDATE_SELF}" || -z "${LIB_BASH_SELF_UPDATE_SELF_MAIN_FUNCTION}" ]]; then
              log_err "LIB_BASH_SELF_UPDATE_SELF and function LIB_BASH_SELF_UPDATE_SELF_MAIN_FUNCTION must be defined in the calling script"
              exit 1
            fi
            if ! declare -F "${LIB_BASH_SELF_UPDATE_SELF_MAIN_FUNCTION}" >/dev/null 2>&1 ; then
              log_err "the main function ${LIB_BASH_SELF_UPDATE_SELF_MAIN_FUNCTION} must be defined in the calling script"
              exit 1
            fi
        fi

        if ! is_lib_bash_up_to_date; then
            if check_self_update_ownership "${LIB_BASH_SELF_UPDATE_SELF}"; then
                LIB_BASH_SELF_UPDATE_SELF_DIR=$(dirname "${LIB_BASH_SELF_UPDATE_SELF}")
                if lib_bash_update_myself; then
                    log "Successfully updated! Restarting..."
                    # Restart Bash without config files, load the script's library, and run its main function.
                    exec "${BASH}" --noprofile --norc -c \
                        "source '${LIB_BASH_SELF_UPDATE_SELF}' && '${LIB_BASH_SELF_UPDATE_SELF_MAIN_FUNCTION}' \"\$@\"" \
                        _ "$@"
                else
                    local ret=$?
                    log_err "Update failed with error code $ret"
                    return $ret
                fi
            fi
        fi
}

if ! declare -F "source_lib_bash_dependencies" >/dev/null 2>&1
then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_bash.sh"
fi
