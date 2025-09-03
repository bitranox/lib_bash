che# lib_bash - Bash Utility Library

[![License: GPL3](https://img.shields.io/badge/License-GPL3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
![Bash Version](https://img.shields.io/badge/Bash-4.4%2B-lightgrey)

a small Bash scripting library with system administration utilities, logging mechanisms, and self-updating capabilities.  
the functions marked as "OLD" are ridiculouse, don't use them, they will be replaced or deleted, but the new functions are useful.

## Features

- **System Maintenance**
  - Automated package updates
  - Dependency management
  - Phased update handling
  - System cleanup operations

- **Logging System**
  - Multi-channel logging (persistent/temporary)
  - Color-coded output
  - Error/warning differentiation

- **Security Features**
  - Sudo/SSH-ASKPASS integration
  - User permission management
  - Root access control

- **Advanced Utilities**
  - Email notifications
  - File manipulation tools
  - Assertion testing framework
  - Self-updating mechanism
  - Temporary path management (temp files/dirs) – see docs/README_lib_bash_tempfiles.md

- **Compatibility**
  - Cross-distribution support
  - Error handling with retry logic
  - Safe package marking preservation

## Installation

```bash
sudo git clone --depth 1 https://github.com/bitranox/lib_bash.git /usr/local/lib_bash
/usr/local/lib_bash/lib_bash.sh log "Hello World"
```

## Configuration

Set environment variables in your script/shell:

```bash
export LIB_BASH_LOGFILE="/var/log/myapp.log"
export LIB_BASH_LOGFILE_ERR="/var/log/myapp_errors.log"
```

## Key Functions

### System Updates
```bash
linux_update  # Full system update with cleanup
```
Note: linux_update is implemented in lib_bash_linux_update.sh and is auto-sourced by lib_bash.sh; no extra imports needed.


### Logging
```bash
log "System update started"
log_err "Critical error occurred"
log_warn "Warning: Low disk space"
```

### Package Management
```bash
install_package_if_not_present "nginx" "True"
reinstall_keep_marking "openssl"
```

### File Operations
```bash
lib_bash_prepend_text_to_file "# Security Settings" "/etc/config"
backup_file "/etc/nginx.conf"
```

### Temporary Paths
```bash
# Create and auto-register
f=$(create_temp_file)
d=$(create_temp_dir)

# Registry helpers
list_temppaths
print_temppath_registry
unregister_temppath "$f"

# Clean up everything on script exit
trap 'cleanup_temppaths' EXIT
```
See `docs/README_lib_bash_tempfiles.md` for full API and examples.

### Assertions
```bash
# String output assertions
assert_equal    "my_func arg" "expected output"
assert_contains "echo 'foo bar'" "foo"

# Return code assertions
assert_return_code "false" 1
assert_pass        "true"
assert_fail        "false"
```
See `docs/README_lib_assert.md` for full API and examples.

## Self-Updating System

The library automatically checks for updates:
```bash
# On next execution, updates will be applied
_lib_bash_self_update  # Manual update check
```

To suppress self-update (e.g., in CI, tests, or restricted environments), set:

```bash
export LIB_BASH_DISABLE_SELF_UPDATE=1
```

When this variable is set, lib_bash.sh will skip the self-update logic entirely.

## Log Files

Default locations depend on privilege and script name.

- As user: `${XDG_STATE_HOME:-$HOME/.local/state}/lib_bash/<script>.log`
- As root: `/var/log/lib_bash/<script>.log`

Companion files are created alongside the main log:

- Temporary Log: `<script>_tmp.log`
- Error Log: `<script>_err.log`
- Temporary Error Log: `<script>_err_tmp.log`

Note on `<script>` naming:
- `<script>` equals the output of `get_script_stem()` from `lib_bash.sh`.
- It takes the script basename and strips only the last extension (e.g., `backup.sh` → `backup`).
- Dotfiles are preserved unchanged (e.g., `.env` remains `.env`).

## Dependencies

- Coreutils
- Git (for self-updating)
- Mutt (for email functionality)
- SSH-ASKPASS (for GUI password prompts)

## License

GNU General Public License v3.0 - See [LICENSE](https://github.com/bitranox/lib_bash/blob/master/docs/LICENSE)

## Contributing

1. Fork the repository
2. Create feature branch
3. Submit PR with detailed description

```bash
# Development setup
git clone git@github.com:your_username/lib_bash.git
cd lib_bash
# Create virtual environment recommended
# Disable self-update during local dev/CI
export LIB_BASH_DISABLE_SELF_UPDATE=1
```

## Maintainer

Initial Author: bitranox

---

**Important**: Test thoroughly before production use. Some operations require root privileges - ensure proper authorization.
```
