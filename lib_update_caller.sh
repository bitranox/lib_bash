#!/usr/bin/env bash
# lib_update_caller.sh — Self-update helper for the calling script (Git-based)
#
# Purpose:
# - If the caller lives in a Git checkout, fetch and fast-forward to origin/HEAD
#   and then re-exec the caller with original arguments.
#
# Usage:
# - In your script: `source /usr/local/lib_bash/lib_update_caller.sh && update_caller "$@"`
#
# Notes:
# - No-op if not in a Git repository or already up to date.
# - Strict mode only when executed directly; safe to source as a library.

# For detection if the script is sourced correctly
# shellcheck disable=SC2034
LIB_UPDATE_CALLER_LOADED=true

_lib_update_caller_is_in_script_mode() {
  case "${BASH_SOURCE[0]}" in
    "${0}") return 0 ;;  # script mode
    *)      return 1 ;;
  esac
}

# --- only in script mode ---
if _lib_update_caller_is_in_script_mode; then
  # Strict mode & traps only when run directly
  set -Eeuo pipefail
  IFS=$'\n\t'
  umask 022
  # shellcheck disable=SC2154
  trap 'ec=$?; echo "ERR $ec at ${BASH_SOURCE[0]}:${LINENO}: ${BASH_COMMAND}" >&2' ERR
fi

# Get the directory of the script that sourced this file
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[1]}")")"  # directory of the caller script

function update_caller {
    # Preserve original arguments to re-exec after update
    local original_args=("$@")

    # Read current commit hash of the caller's repository (if any)
    local current_hash
    current_hash=$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null)

    # Fetch updates and obtain remote HEAD hash (ignore output in non-git dirs)
    git -C "$SCRIPT_DIR" fetch --quiet >/dev/null 2>&1
    local remote_hash
    remote_hash=$(git -C "$SCRIPT_DIR" rev-parse origin/HEAD 2>/dev/null)

    # If a newer revision is available, reset hard and re-exec the caller
    if [[ "$remote_hash" && "$remote_hash" != "$current_hash" ]]; then
        echo "🔧 Updating to new version: ${remote_hash:0:7}"
        git -C "$SCRIPT_DIR" reset --hard origin/HEAD --quiet >/dev/null 2>&1
        # Restart with original arguments
        exec "$(readlink -f "${BASH_SOURCE[1]}")" "${original_args[@]}"
    fi
}
