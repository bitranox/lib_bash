#!/bin/bash
# Self-update library
# 2025-01-24
##############################################################################
# USAGE
##############################################################################

##!/bin/bash
## Main script that sources the self-update library
## Define critical paths in the MAIN script (not in the library)
## declare -r LIB_BASH_SELF=$(readlink -f "${BASH_SOURCE[0]}")
## declare -r LIB_BASH_DIR=$(dirname "${LIB_BASH_SELF}")
## Source dependencies
#source "/usr/local/lib_bash/self_update.sh"       # Self-update logic
#source "/some/directory/other_dependencies.sh"    # Other functions
# function MAIN {     # the name MUST BE MAIN !!!!
#     ... (your existing main logic)
# }

# Initial execution flow
#lib_bash_self_update "$@"
#MAIN "$@"

##############################################################################
# UPDATE MYSELF
##############################################################################

# Dependency check (ensure these are defined in the main script)
if [[ -z "${LIB_BASH_SELF}" || -z "${LIB_BASH_DIR}" || -z "${MAIN}" ]]; then
  echo "ERROR: LIB_BASH_SELF and LIB_BASH_DIRand MAIN must be defined in the main script" >&2
  exit 1
fi

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
    default_branch=$(git -C "${LIB_BASH_DIR}" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@') || {
        log_err "Failed to determine default branch"
        return 2
    }

    # Get remote hash
    git_remote_hash=$(git -C "${LIB_BASH_DIR}" ls-remote origin --heads "${default_branch}" | awk '{print $1}') || {
        log_err "Failed to get remote hash"
        return 3
    }

    # Get local hash
    git_local_hash=$(git -C "${LIB_BASH_DIR}" rev-parse HEAD) || {
        log_err "Failed to get local hash"
        return 4
    }

    [[ "${git_remote_hash}" == "${git_local_hash}" ]] && return 0
    return 1
}

function lib_bash_update_myself {
    local default_branch
    (
        set -eo pipefail
        cd "${LIB_BASH_DIR}" || exit 99

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

function lib_bash_self_update {
    if ! is_lib_bash_up_to_date; then
        log "Update available! Performing self-update..."
        if lib_bash_update_myself; then
            log "Successfully updated! Restarting..."
            # Restart Bash without config files, load the script's library, and run its main function.
            exec "${BASH}" --noprofile --norc -c \
                "source '${LIB_BASH_SELF}' && main \"\$@\"" \
                _ "$@"
        else
            local ret=$?
            log_err "Update failed with error code $ret"
            return $ret
        fi
    fi
}

if ! declare -F "source_lib_bash_dependencies" >/dev/null 2>&1
then
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_helpers.sh"
fi
