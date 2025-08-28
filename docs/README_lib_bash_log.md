
# lib_bash_log.sh – Advanced Logging Library for Bash

![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Part of lib_bash](https://img.shields.io/badge/Part%20of-lib__bash-ffdd00.svg)

**Part of the [lib_bash](https://github.com/bitranox/lib_bash) collection** – A robust utility suite for professional Bash scripting.

---

## 🔧 Overview

This module provides structured, colored, and level-based logging for Bash scripts. It supports multi-file logging, command output tracking, and debug toggling — all with minimal configuration.

---

## 🚀 Quick Start

```bash
#!/bin/bash
source /usr/local/lib_bash/lib_bash.sh

log "Deploying application..."
log_ok "Deployment successful"
log_wrench "Setting up config..."
log_warn "Using fallback configuration"
log_err "Connection failed"
log_debug "Debug info: $var"

logc ls -la /nonexistent
```

---

## ✨ Features

- Multiple log levels: `log`, `log_ok`, `log_warn`, `log_err`, `log_debug`
- Emoji and color-enhanced terminal output
- Logs split into: general log, error log, temporary logs
- Command execution with logging: `logc`, `logc_err`
- Automatic log path initialization (based on script and privilege)
- Debug mode toggle via `LIB_BASH_DEBUG_MODE`
- Integrated with `lib_color.sh` and `lib_bash.sh`

> ⚠️ This library is **not standalone**. Requires components from `lib_bash` (e.g., `lib_color.sh`, `lib_bash.sh`).

---

## 📦 Installation

```bash
sudo git clone --depth 1 https://github.com/bitranox/lib_bash.git /usr/local/lib_bash
source /usr/local/lib_bash/lib_bash.sh
```

---

## 🛠️ Usage

### Basic Logging

```bash
log_wrench "Setting up environment"
log "Info message"
log_ok "Success message"
log_wrench "Tweaking message"
log_warn "Warning message"
log_err "Error message"
log_debug "Visible only in debug mode"
```

### Command Output Logging

```bash
logc whoami          # Logs stdout, stderr goes to error log if command fails
logc_err uptime      # Logs everything as error regardless of exit status
```

### Enable Debug Mode

```bash
export LIB_BASH_DEBUG_MODE=ON
log_debug "Debug logging enabled"
```

---

## 📂 Log Files

Log files are created based on the script name and user privilege:

| Variable                   | Description                |
|---------------------------|----------------------------|
| `LIB_BASH_LOGFILE`         | Main log                   |
| `LIB_BASH_LOGFILE_TMP`     | Session-specific log       |
| `LIB_BASH_LOGFILE_ERR`     | Error log                  |
| `LIB_BASH_LOGFILE_ERR_TMP` | Session-specific error log |

Paths:

- As **root**: `/var/log/lib_bash/`
- As **user**: `${XDG_STATE_HOME:-$HOME/.local/state}/lib_bash/`

Note on `<script>` naming:
- The actual filenames are based on the script stem returned by `get_script_stem()` from `lib_bash.sh`.
- It uses the script basename and strips only the last extension (e.g., `deploy.sh` → `deploy`).
- Dotfiles are preserved unchanged (e.g., `.env` stays `.env`).

Temporary logs are registered for cleanup.

---

## 🎨 Color Output

Colors and symbols help differentiate log levels:

- **log** → `clr_green` ℹ️
- **log_ok** → `clr_green` ✔️
- **log_wrench** → `clr_green` 🔧
- **log_warn** → `clr_yellow` ⚠️
- **log_err** → `clr_cyan` ❌
- **log_debug** → `clr_magentab clr_yellow` 🐞

Reset colors:

```bash
_set_default_logfile_colors RESET
```

---

## 🔍 API Summary

| Function     | Description                                  |
|--------------|----------------------------------------------|
| `log`        | General log message                          |
| `log_ok`     | Success message                              |
| `log_wrench` | Task or process message (uses wrench emoji) |
| `log_warn`   | Warning message                              |
| `log_err`    | Error message + logs to error files          |
| `log_debug`  | Debug message (if debug mode is enabled)     |
| `logc`       | Log stdout/stderr from command               |
| `logc_err`   | Log all command output as error              |

---

## ⚙️ Internal Functions

| Function                   | Purpose                                   |
|---------------------------|-------------------------------------------|
| `_set_default_logfiles`    | Setup log file paths                      |
| `_set_default_logfile_colors` | Configure default colors                |
| `_set_default_debugmode`   | Initialize debug mode                     |
| `_create_log_dir`          | Ensure log directory exists               |
| `_log`                     | Internal: format and dispatch log output  |

---

## 📋 Requirements

- **Bash** 4.0+
- Works on **Linux** and **macOS**
- Requires `lib_color.sh`, `lib_bash.sh`

---

## 🌐 Related Modules

- **lib_color.sh** – Terminal color formatting
- **lib_bash.sh** – Environment setup, utility functions
- **lib_retry.sh** – Automatic retries for failing commands
- **self_update.sh** – Self-updating script mechanism

[Explore All Modules →](https://github.com/bitranox/lib_bash)

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

See [CONTRIBUTING.md](https://github.com/bitranox/lib_bash/blob/master/docs/CONTRIBUTING.md)

---

*Tested on: Linux, macOS*  
*Part of the [lib_bash](https://github.com/bitranox/lib_bash) toolkit for maintainable scripting.*
