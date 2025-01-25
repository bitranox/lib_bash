#!/usr/bin/env bash

# Get the directory of the script that sourced this file
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[1]}")")"

function update_myself() {
    # Store original arguments
    local original_args=("$@")

    # Get current commit hash
    local current_hash
    current_hash=$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null)

    # Fetch updates and check remote hash
    git -C "$SCRIPT_DIR" fetch --quiet >/dev/null 2>&1
    local remote_hash
    remote_hash=$(git -C "$SCRIPT_DIR" rev-parse origin/HEAD 2>/dev/null)

    # Update if newer version exists
    if [[ "$remote_hash" && "$remote_hash" != "$current_hash" ]]; then
        echo "Updating to new version: ${remote_hash:0:7}"
        git -C "$SCRIPT_DIR" reset --hard origin/HEAD --quiet >/dev/null 2>&1
        # Restart with original arguments
        exec "$(readlink -f "${BASH_SOURCE[1]}")" "${original_args[@]}"
    fi
}
