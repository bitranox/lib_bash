#!/bin/bash
# tests/test_lib_bash_tempfiles.sh
#
# Test suite for lib_bash_tempfiles.sh with 100% coverage of all functions.

set -o errexit -o nounset -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib_bash_tempfiles.sh"

# Validate library sourcing
if [[ -z "$LIB_BASH_TEMPFILES_LOADED" ]]; then
    echo "Error: lib_bash_tempfiles.sh not sourced correctly!" >&2
    exit 1
fi
echo "lib_bash_tempfiles.sh sourced successfully."

TESTS_RUN=0
TESTS_FAILED=0

# --- Assertion Function ---
assert() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    ((++TESTS_RUN))

    if [[ "$actual" == "$expected" ]]; then
        echo "✓ $message"
    else
        ((++TESTS_FAILED))
        echo "✗ $message"
        echo "  Expected: '$expected'"
        echo "  Got:      '$actual'"
    fi
}

# ------------------------------------------------------------------------------
# test__set_tempfile_management()
# Ensures it creates the registry file and doesn't break if called repeatedly.
# ------------------------------------------------------------------------------
test__set_tempfile_management() {
    echo "Testing _set_tempfile_management..."

    # Backup original registry path
    local old_list="${_TMP_LIB_BASH_TEMPFILES_PATHS_LIST:-}"

    # Unset to force re-initialization
    unset _TMP_LIB_BASH_TEMPFILES_PATHS_LIST

    _set_tempfile_management

    # Check that the file is defined and exists
    if [[ -z "${_TMP_LIB_BASH_TEMPFILES_PATHS_LIST}" ]]; then
        echo "✗ _TMP_LIB_BASH_TEMPFILES_PATHS_LIST is not set"
        ((++TESTS_FAILED))
    else
        if [[ -f "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST" ]]; then
            echo "✓ Registry file exists: $_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"
        else
            echo "✗ Registry file missing"
            ((++TESTS_FAILED))
        fi
    fi

    # Idempotency: call again
    _set_tempfile_management
    echo "✓ Re-running _set_tempfile_management doesn't cause errors"

    # Restore
    _TMP_LIB_BASH_TEMPFILES_PATHS_LIST="$old_list"
}

# ------------------------------------------------------------------------------
# test__get_number_of_registered_paths()
# Checks if line counting works as intended.
# ------------------------------------------------------------------------------
test__get_number_of_registered_paths() {
    echo "Testing _get_number_of_registered_paths..."

    # Ensure registry is clean
    : > "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"
    assert "0" "$(_get_number_of_registered_paths)" "Empty registry yields 0"

    # Add lines manually
    echo "/some/path" >> "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"
    echo "/another/path" >> "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"
    assert "2" "$(_get_number_of_registered_paths)" "Two lines in registry"

    # Clear
    : > "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"
    assert "0" "$(_get_number_of_registered_paths)" "Cleared registry yields 0"
}

# ------------------------------------------------------------------------------
# test_register_temppath()
# Tests registering a path (files, duplicates, symlinks, realpath usage, etc.).
# ------------------------------------------------------------------------------
test_register_temppath() {
    echo "Testing register_temppath..."

    # Clean out the registry
    : > "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"

    # 1) Test empty path
    local output exit_code
    set +o errexit
    output=$(register_temppath "" 2>&1)
    exit_code=$?
    set -o errexit
    assert "1" "$exit_code" "register_temppath with empty path returns 1"
    echo "$output" | grep -q "Path required"
    assert "0" "$?" "Logs error for empty path"

    # 2) Valid file
    local temp_file
    temp_file="$(mktemp)"
    register_temppath "$temp_file"
    assert "0" "$?" "register_temppath with file returns 0"
    local lines
    lines="$(_get_number_of_registered_paths)"
    assert "1" "$lines" "One path in registry after registering a file"
    rm -f "$temp_file"

    # 3) Valid directory
    local temp_dir
    temp_dir="$(mktemp -d)"
    register_temppath "$temp_dir"
    assert "0" "$?" "register_temppath with directory returns 0"
    lines="$(_get_number_of_registered_paths)"
    assert "2" "$lines" "Two paths in registry after registering a dir"
    rm -rf "$temp_dir"

    # 4) Duplicate registration
    register_temppath "$temp_file"
    lines="$(_get_number_of_registered_paths)"
    assert "2" "$lines" "No duplicate lines in registry file"

    # 5) Symlink handling (if realpath is available)
    if command -v realpath &>/dev/null; then
        local target symlink
        target="$(mktemp)"
        symlink="$(mktemp -u)"  # name for symlink
        ln -sf "$target" "$symlink"

        : > "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"
        register_temppath "$symlink"
        assert "0" "$?" "register_temppath with symlink returns 0"
        local resolved
        resolved="$(realpath -m "$symlink")"

        grep -Fxq "$resolved" "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"
        assert "0" "$?" "Symlink resolved in registry file"

        rm -f "$target" "$symlink"
    else
        echo "Skipping symlink test (realpath not available)"
    fi

    # Clean registry
    : > "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"
}

# ------------------------------------------------------------------------------
# test_create_temp_file()
# Covers normal usage, optional template, invalid template, mktemp failure, etc.
# ------------------------------------------------------------------------------
test_create_temp_file() {
    echo "Testing create_temp_file..."

    : > "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"  # Clear registry

    # 1) Basic usage (no template)
    local lines
    local tf
    tf="$(create_temp_file)"
    assert "0" "$?" "create_temp_file (no template) returns success"
    [[ -f "$tf" ]] && echo "✓ Temp file exists" || echo "✗ Temp file missing"
    lines="$(_get_number_of_registered_paths)"
    assert "1" "$lines" "Temp file registered in registry"

    rm -f "$tf"
    : > "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"

    # 2) Template with >=6 X's
    local tf_template
    tf_template="$(create_temp_file "/tmp/tfile.XXXXXX")"
    assert "0" "$?" "create_temp_file with valid template"
    [[ -f "$tf_template" ]] && echo "✓ Temp file (template) exists" || echo "✗ Temp file (template) missing"
    lines="$(_get_number_of_registered_paths)"
    assert "1" "$lines" "Temp file (template) registered"
    rm -f "$tf_template"
    : > "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"

    # 3) Invalid template (not enough X's)
    set +o errexit
    local out
    out="$(create_temp_file "/tmp/badtemplate.XXX" 2>&1)"
    local ec=$?
    set -o errexit
    assert "1" "$ec" "create_temp_file invalid template returns error"
    echo "$out" | grep -q "Template must end with at least six"
    assert "0" "$?" "Logs error about invalid template"

    # 4) mktemp fails (simulate by unwritable directory)
    local unwritable
    unwritable="$(mktemp -d)"
    chmod 500 "$unwritable"
    # We pass a template inside the unwritable dir
    set +o errexit
    out="$(create_temp_file "$unwritable/something.XXXXXX" 2>&1)"
    ec=$?
    set -o errexit
    assert "1" "$ec" "create_temp_file fails if mktemp can't create file"
    echo "$out" | grep -q "Failed to create temporary file"
    assert "0" "$?" "Logs error on mktemp failure"

    chmod 700 "$unwritable"
    rm -rf "$unwritable"
    : > "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"
}

# ------------------------------------------------------------------------------
# test_create_temp_dir()
# Covers normal usage, optional template, invalid template, mktemp -d failure, etc.
# ------------------------------------------------------------------------------
test_create_temp_dir() {
    echo "Testing create_temp_dir..."

    : > "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"

    # 1) Basic usage (no template)
    local td
    local lines
    td="$(create_temp_dir)"
    assert "0" "$?" "create_temp_dir (no template) success"
    [[ -d "$td" ]] && echo "✓ Temp dir exists" || echo "✗ Temp dir missing"
    lines="$(_get_number_of_registered_paths)"
    assert "1" "$lines" "Temp dir registered"
    rm -rf "$td"
    : > "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"

    # 2) Template with >=6 X's
    local td_template
    td_template="$(create_temp_dir "/tmp/tdir.XXXXXX")"
    assert "0" "$?" "create_temp_dir with valid template"
    [[ -d "$td_template" ]] && echo "✓ Temp dir (template) exists" || echo "✗ Temp dir (template) missing"
    lines="$(_get_number_of_registered_paths)"
    assert "1" "$lines" "Temp dir (template) registered"
    rm -rf "$td_template"
    : > "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"

    # 3) Invalid template
    set +o errexit
    local out ec
    out="$(create_temp_dir "/tmp/baddir.XXX" 2>&1)"
    ec=$?
    set -o errexit
    assert "1" "$ec" "create_temp_dir invalid template returns error"
    echo "$out" | grep -q "Template must end with at least six"
    assert "0" "$?" "Logs error about invalid dir template"

    # 4) mktemp -d failure (unwritable directory)
    local unwritable2
    unwritable2="$(mktemp -d)"
    chmod 500 "$unwritable2"
    set +o errexit
    out="$(create_temp_dir "$unwritable2/mydir.XXXXXX" 2>&1)"
    ec=$?
    set -o errexit
    assert "1" "$ec" "create_temp_dir fails if mktemp -d can't create dir"
    echo "$out" | grep -q "Failed to create temporary directory"
    assert "0" "$?" "Logs error on mktemp -d failure"

    chmod 700 "$unwritable2"
    rm -rf "$unwritable2"
    : > "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"
}

# ------------------------------------------------------------------------------
# test_cleanup_temppaths()
# Verifies two-pass cleanup logic (files first, dirs second), success/failure.
# ------------------------------------------------------------------------------
test_cleanup_temppaths() {
    echo "Testing cleanup_temppaths..."

    : > "$_TMP_LIB_BASH_TEMPFILES_PATHS_LIST"
    _TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_FILES=()
    _TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_DIRS=()

    # 1) Successful cleanup
    local f1 d1
    f1="$(mktemp)"
    d1="$(mktemp -d)"
    register_temppath "$f1"
    register_temppath "$d1"
    cleanup_temppaths
    assert "0" "$?" "Successful cleanup exit code"
    assert "0" "$(_get_number_of_registered_paths)" "Registry file cleared"
    [[ ! -e "$f1" ]] && echo "✓ File removed" || echo "✗ File not removed"
    [[ ! -d "$d1" ]] && echo "✓ Dir removed" || echo "✗ Dir not removed"

    # 2) Failed file removal (parent not writable)
    local bad_dir
    bad_dir="$(mktemp -d)"
    local protected_file="$bad_dir/prot_file"
    touch "$protected_file"
    chmod a-w "$bad_dir"
    register_temppath "$protected_file"

    set +o errexit
    cleanup_temppaths
    local ec=$?
    set -o errexit
    assert "1" "$ec" "Failed file cleanup exit code"
    assert "1" "${#_TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_FILES[@]}" "Failed file recorded"
    chmod a+w "$bad_dir"
    rm -rf "$bad_dir"

    # 3) Failed dir removal (non-empty)
    local nonempty
    nonempty="$(mktemp -d)"
    touch "$nonempty/somefile"
    register_temppath "$nonempty"
    set +o errexit
    cleanup_temppaths
    ec=$?
    set -o errexit
    assert "1" "$ec" "Failed dir cleanup exit code"
    assert "1" "${#_TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_DIRS[@]}" "Failed dir recorded"
    rm -rf "$nonempty"

    echo "✓ cleanup_temppaths tests completed"
}

# ------------------------------------------------------------------------------
# main() - runs all tests
# ------------------------------------------------------------------------------
main() {
    echo "Running test suite..."

    test__set_tempfile_management
    test__get_number_of_registered_paths
    test_register_temppath
    test_create_temp_file
    test_create_temp_dir
    test_cleanup_temppaths

    echo
    echo "Test Summary:"
    echo "Tests run: $TESTS_RUN"
    if (( TESTS_FAILED > 0 )); then
        echo "Tests failed: $TESTS_FAILED"
        exit 1
    else
        echo "All tests passed!"
    fi
}

# If this file is invoked directly, run main().
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
