# lib\_bash\_log.sh - Logging Library for Bash Scripts

![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Part of lib\_bash](https://img.shields.io/badge/Part%20of-lib__bash-ffdd00.svg)

Part of the [lib\_bash](https://github.com/bitranox/lib_bash) collection – A powerful Bash scripting utilities library.

---

## Quick Example

You can **source** this library from within your script to enable structured, colored logging with error tracking:

```bash
#!/bin/bash
source /usr/local/lib_bash/lib_bash.sh

log "Starting deployment..."
log_warn "Running in test mode"
log_err "Something went wrong"
log_debug "Internal variable: $foo"

logc ls -l /nonexistent
```

---

## Features

* Log to multiple files: main log, error log, and temporary session logs
* Structured logging with log levels: `log`, `log_warn`, `log_err`, `log_debug`
* Colored and styled terminal output (requires `lib_color.sh`)
* Debug mode toggle
* Automatic temporary log cleanup support
* Command wrappers: `logc`, `logc_err` for logging command output

> **Note**: This script **requires** other components from `lib_bash` (`lib_color.sh`, `lib_bash.sh`) and **cannot be used standalone**.

---

## Installation

### As part of lib\_bash

```bash
sudo git clone --depth 1 https://github.com/bitranox/lib_bash.git /usr/local/lib_bash
source /usr/local/lib_bash/lib_bash.sh
```

---

## Usage

### Basic Logging

```bash
log "Standard log message"
log_warn "This is a warning"
log_err "Something failed"
log_debug "This will only show if debug mode is ON"
```

### Enable Debug Mode

```bash
export LIB_BASH_DEBUG_MODE=ON
log_debug "Now this will appear"
```

### Log Command Output

```bash
logc df -h         # Logs stdout, logs stderr as error
logc_err uname -a  # Logs everything as error
```

---

## Log Files

Depending on whether the script is run as root or not, log files are placed under:

* `/var/log/lib_bash/` (as root)
* `$HOME/log/lib_bash/` (non-root)

The log file names are based on the script name:

| Variable                   | Purpose                |
| -------------------------- | ---------------------- |
| `LIB_BASH_LOGFILE`         | Main log file          |
| `LIB_BASH_LOGFILE_TMP`     | Temp session log       |
| `LIB_BASH_LOGFILE_ERR`     | Error-only log file    |
| `LIB_BASH_LOGFILE_ERR_TMP` | Temp session error log |

Temporary logs are auto-registered for cleanup if `register_temppath` is available.

---

## Colored Output

Colorization is handled via functions from `lib_color.sh`:

* Normal: `clr_green`
* Bold: `clr_bold clr_green`
* Warnings: `clr_bold clr_yellow`
* Errors: `clr_bold clr_cyan`
* Debug: `clr_bold clr_magentab clr_yellow`

Colors can be reset or customized by calling:

```bash
_set_default_logfile_colors RESET
```

---

## API Overview

### Public Functions

| Function    | Description                               |
| ----------- | ----------------------------------------- |
| `log`       | Standard message with optional color      |
| `log_warn`  | Warning message                           |
| `log_err`   | Error message + logs to error files       |
| `log_debug` | Debug message (only if debug mode is ON)  |
| `logc`      | Run command and log output (log or error) |
| `logc_err`  | Run command and always log as error       |

---

## Internal Setup Functions

These are called automatically:

* `_set_default_logfiles` – Initializes log file paths
* `_set_default_logfile_colors` – Initializes color settings
* `_set_default_debugmode` – Initializes `LIB_BASH_DEBUG_MODE`
* `_create_log_dir` – Ensures log directories exist
* `_log` – Core logging function (used internally)

---

## Requirements

* **Bash 4.0+**
* Requires `lib_bash` (especially: `lib_color.sh`, `lib_bash.sh`)
* Linux or macOS with typical file permissions

---

## License

GNU General Public License v3.0 – See [LICENSE](https://github.com/bitranox/lib_bash/blob/master/docs/LICENSE) for details.

---

## lib\_bash Ecosystem

This script is part of a comprehensive Bash scripting suite:

* **lib\_color.sh** – Terminal color formatting
* **lib\_bash.sh** – Utility functions and environment setup
* **lib\_retry.sh** – Retry failed commands automatically
* **self\_update.sh** – Make your script self-updating

[View all modules...](https://github.com/bitranox/lib_bash)

---

## Contributing

We welcome contributions! Just:

1. Fork the repo
2. Create a feature branch
3. Make your changes
4. Submit a Pull Request

For details, see: [CONTRIBUTING.md](https://github.com/bitranox/lib_bash/blob/master/docs/CONTRIBUTING.md)

---

*Tested on: Linux, macOS*
*Part of the [lib\_bash](https://github.com/bitranox/lib_bash) professional scripting toolkit.*
