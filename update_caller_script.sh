#!/usr/bin/env bash

function get_script_dir() {
    local script_path
    script_path=$(readlink -f "${BASH_SOURCE[1]}")
    dirname "${script_path}"
}

function get_remote_url() {
    local script_dir=$1
    git -C "${script_dir}" config --get remote.origin.url | sed 's/git@github.com:/https:\/\/github.com\//;s/\.git$//'
}

function is_self_up_to_date() {
    local script_dir remote_url git_remote_hash git_local_hash
    script_dir=$(get_script_dir)
    remote_url=$(get_remote_url "${script_dir}")

    git_remote_hash=$(git --no-pager ls-remote --quiet "${remote_url}" | awk '/HEAD/ {print $1}')
    git_local_hash=$(git -C "${script_dir}" rev-parse HEAD 2>/dev/null)

    [[ "${git_remote_hash}" == "${git_local_hash}" ]]
}

function update_myself_scripts() {
    local script_dir
    script_dir=$(get_script_dir)

    (
        cd "${script_dir}" || exit 1
        git fetch --all >/dev/null 2>&1
        git reset --hard origin/HEAD >/dev/null 2>&1
    )
}

function update_myself() {
    local path_to_caller
    path_to_caller=$(readlink -f "${BASH_SOURCE[1]}")
    local original_args=("$@")

    if ! is_self_up_to_date; then
        update_myself_scripts
        exec bash "${path_to_caller}" "${original_args[@]}"
    fi
}
