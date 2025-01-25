# lib_bash - Bash Utility Library

[![License: GPL3](https://img.shields.io/badge/License-GPL3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
![Bash Version](https://img.shields.io/badge/Bash-4.4%2B-lightgrey)

A smal Bash scripting library with system administration utilities, logging mechanisms, and self-updating capabilities.
some of the "OLD" marked functions are rediculouse, but the new functions are useful.

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

- **Compatibility**
  - Cross-distribution support
  - Error handling with retry logic
  - Safe package marking preservation

## Installation

```bash
git clone https://github.com/bitranox/lib_bash.git /usr/local/lib_bash
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

## Self-Updating System

The library automatically checks for updates:
```bash
# On next execution, updates will be applied
_lib_bash_self_update  # Manual update check
```

## Log Files

| File Type                | Default Location                  |
|--------------------------|-----------------------------------|
| Main Log                 | ~/log/lib_bash/lib_bash.log       |
| Temporary Log            | ~/log/lib_bash/lib_bash_tmp.log   |
| Error Log                | ~/log/lib_bash/lib_bash_err.log   |
| Temporary Error Log      | ~/log/lib_bash/lib_bash_err_tmp.log |

## Dependencies

- Coreutils
- Git (for self-updating)
- Mutt (for email functionality)
- SSH-ASKPASS (for GUI password prompts)

## License

GNU General Public License v3.0 - See [LICENSE](https://www.gnu.org/licenses/gpl-3.0.en.html)

## Contributing

1. Fork the repository
2. Create feature branch
3. Submit PR with detailed description

```bash
# Development setup
git clone git@github.com:your_username/lib_bash.git
cd lib_bash
# Create virtual environment recommended
```

## Maintainer

Initial Author: bitranox

---

**Important**: Test thoroughly before production use. Some operations require root privileges - ensure proper authorization.
```
