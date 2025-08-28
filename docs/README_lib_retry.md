# lib_retry.sh - Exponential Backoff Retry for Bash

![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)  
![Part of lib_bash](https://img.shields.io/badge/Part%20of-lib__bash-ffdd00.svg)

Part of the [lib_bash](https://github.com/bitranox/lib_bash) collection – A powerful Bash scripting utilities library.

---

## Quick Example

```bash
#!/bin/bash

# Source the library
source /usr/local/lib_bash/lib_retry.sh

# Sample usage
retry -- echo "Attempting a simple command"

# Or with options
retry -n 3 -d 2 -- ls /some/nonexistent/path
```

- **-n** sets the max number of attempts  
- **-d** sets the base delay for exponential backoff  
- **--** signals the end of options, followed by the command to retry

---

## Features

- **Simple CLI options** for max attempts, base delay, and a custom logger
- **Exponential backoff** with a configurable cap
- **Non-retryable exit codes** can be customized
- **Graceful** handling of system interrupts, command-not-found errors, etc.
- **Environment override** (`RETRY_NON_RETRYABLE`) for special cases
- **Portable** Bash script, no external dependencies (uses built-in `getopts`)

---

## Installation

### As part of lib_bash

```bash
sudo git clone --depth 1 https://github.com/bitranox/lib_bash.git /usr/local/lib_bash
source /usr/local/lib_bash/lib_retry.sh
```

### Standalone usage

```bash
curl -O https://raw.githubusercontent.com/bitranox/lib_bash/master/lib_retry.sh
source lib_retry.sh
```

---

## Usage

You can **source** `lib_retry.sh` in your script or call it directly. The main function is:

```bash
retry [options] -- command [args...]
```

**Options**:  
- **`-n MAX_ATTEMPTS`** : Number of retry attempts (default: 5)  
- **`-d RETRY_DELAY`** : Base delay in seconds for exponential backoff (default: 5)  
- **`-l LOG_FUNC`**    : Name of a logger function (default: `log_err`)

**Non-retryable errors**: `126` (Permission denied), `127` (Command not found), `130` (User interrupt)  
- Override via the environment array `RETRY_NON_RETRYABLE`

**Exponential backoff**:  
- Each retry multiplies the base delay by 2 (with a cap of 300s by default).

---

## Examples

### 1. Simple Command

```bash
retry -- echo "Hello world"
```
- Attempts `echo "Hello world"` up to 5 times, with an exponential backoff starting at 5s.

### 2. Custom Attempts and Delay

```bash
retry -n 3 -d 2 -- ./my_unstable_script.sh
```
- Retries `my_unstable_script.sh` up to 3 times, starting with a 2-second delay, doubling each retry.

### 3. Override Non-Retryable Errors

```bash
# Suppose you want to treat '2' as non-retryable:
export RETRY_NON_RETRYABLE=(2)
retry -- ./some_command
```
- Now exit code 2 will cause retry to halt immediately.

### 4. Custom Logger

```bash
my_logger() {
    echo "[MY_LOGGER] $*" >&2
}

retry -l my_logger -- false
```
- Prints messages with `[MY_LOGGER]` prefix.

---

## API Reference

### `retry [options] -- command [args...]`

| Parameter       | Description                                               |
|-----------------|-----------------------------------------------------------|
| `-n <value>`    | Max attempts (default: 5)                                 |
| `-d <value>`    | Base delay in seconds for backoff (default: 5)            |
| `-l <function>` | Logger function name. If undefined, a fallback logs to stderr. |

- **Returns**:
  - `0` if the command eventually succeeds  
  - The last exit code of the command if retries are exhausted or a non-retryable error occurs

### `RETRY_NON_RETRYABLE`

- **Type**: environment array (bash 4.3+ style or older with `declare -a`)  
- **Default**: `[126 127 130]`  
- Commands exiting with codes in this array will **immediately** halt retries.

---

## Advanced Usage

- **Error messages**: The script automatically logs the exit code and, if recognized, a short message (e.g., `Command invoked cannot execute` for code 126).  
- **Exponential backoff formula**:  
  \[
    \text{actual_delay} = \min(\text{base_delay} \times 2^{(\text{attempt} - 1)}, 300)
  \]
- **Integration with other scripts**: Just define a custom logger function (e.g. `log_info`, `log_warn`, etc.) and pass it via `-l`.  

---

## Requirements

- Bash 4.0+  
- A logger function if you use `-l`, otherwise a built-in fallback logs to stderr  
- Standard UNIX commands (`sleep`, etc.)

---

## License

GNU General Public License v3.0 – See [LICENSE](https://github.com/bitranox/lib_bash/blob/master/docs/LICENSE) for details.

---

## lib_bash Ecosystem

Part of a comprehensive Bash utilities collection:

- **lib_color.sh** – Terminal color formatting  
- **lib_bash.sh** – A bunch of small helpers and environment setups  
- **lib_retry.sh** – (This library) Retry logic with exponential backoff  
- **self_update.sh** – Make your script self-updating  
- [View all modules...](https://github.com/bitranox/lib_bash)

---

## Contributing

1. Fork the repository  
2. Create a feature branch  
3. Commit your changes  
4. Submit a Pull Request  

See [CONTRIBUTING.md](https://github.com/bitranox/lib_bash/blob/master/CONTRIBUTING.md) for more details.

---

*Tested on: Linux, macOS.  
*Part of the [lib_bash](https://github.com/bitranox/lib_bash) professional scripting toolkit.*
