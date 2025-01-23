#!/bin/bash
set -eo pipefail

# Configuration
readonly LIB_BASH_INSTALL_DIR="/usr/local/lib_bash"
readonly LIB_BASH_REPO_URL="https://github.com/bitranox/lib_bash.git"

# Initialize environment
function initialize_environment {
    local sudo_askpass
    sudo_askpass="$(command -v ssh-askpass 2>/dev/null || true)"

    if [[ -n "$sudo_askpass" ]]; then
        export SUDO_ASKPASS="${sudo_askpass}"
        export NO_AT_BRIDGE=1
    fi
}

# Dependency management
function include_dependencies {
    local my_dir
    my_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

    if [[ -f "${my_dir}/lib_helpers.sh" ]]; then
        source "${my_dir}/lib_helpers.sh"
    else
        echo "Error: Missing required dependency lib_helpers.sh" >&2
        return 1
    fi
}

# File permission functions
function get_octal_permission {
    local file="$1"
    if [[ -e "$file" ]]; then
        stat -c "%a" "$file"
    else
        echo "Error: File '$file' does not exist" >&2
        return 1
    fi
}

function verify_permission {
    local file="$1"
    local permission="$2"
    [[ "$(get_octal_permission "$file")" == "$permission" ]]
}

# Installation functions
function set_lib_bash_permissions {
    local user
    user="$(id -un)"

    sudo_if_needed chmod -R 0755 "$LIB_BASH_INSTALL_DIR"
    sudo_if_needed find "$LIB_BASH_INSTALL_DIR" -type f -name '*.sh' -exec chmod -x {} +
    sudo_if_needed chown -R "${user}:${user}" "$LIB_BASH_INSTALL_DIR" || {
        echo "Warning: Failed to set ownership" >&2
        return 1
    }
}

function sudo_if_needed {
    if [[ -w "$LIB_BASH_INSTALL_DIR" ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

function verify_installation {
    [[ -f "${LIB_BASH_INSTALL_DIR}/install_or_update.sh" ]]
}

function check_repository_state {
    local remote_hash local_hash
    remote_hash=$(git ls-remote --quiet "$LIB_BASH_REPO_URL" HEAD | awk '{print $1}')
    local_hash=$(git -C "$LIB_BASH_INSTALL_DIR" rev-parse HEAD 2>/dev/null || true)

    [[ "$remote_hash" == "$local_hash" ]]
}

# Repository operations
function install_lib_bash {
    echo "Installing lib_bash..."

    sudo_if_needed rm -rf "$LIB_BASH_INSTALL_DIR"
    sudo_if_needed git clone "$LIB_BASH_REPO_URL" "$LIB_BASH_INSTALL_DIR"
    set_lib_bash_permissions
}

function update_lib_bash {
    log "Updating lib_bash..."

    (
        cd "$LIB_BASH_INSTALL_DIR" || fail "Failed to access installation directory"
        sudo_if_needed git fetch --all
        sudo_if_needed git reset --hard origin/master
    )
    set_lib_bash_permissions
}

# Main execution flow
function main {
    initialize_environment
    include_dependencies || return 1

    if ! verify_installation; then
        install_lib_bash
        exec "$LIB_BASH_INSTALL_DIR/install_or_update.sh" "$@"
    fi

    if ! check_repository_state; then
        update_lib_bash
        exec "$LIB_BASH_INSTALL_DIR/install_or_update.sh" "$@"
    fi

    return 0
}

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi