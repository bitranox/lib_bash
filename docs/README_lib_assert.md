# lib_assert.sh – Lightweight Assertions for Bash

![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Part of lib_bash](https://img.shields.io/badge/Part%20of-lib__bash-ffdd00.svg)

Part of the lib_bash collection – a utility suite for professional Bash scripting.

---

## Overview

`lib_assert.sh` provides simple, readable test-style assertions for Bash scripts. It evaluates commands, compares their output or exit codes, and prints clear, colorized failure messages without aborting your script.

- Compare exact output or substring matches.
- Assert specific return codes, generic pass/fail.
- Helpful failure banner with file, test, result, expected, and assert function name.
- Safe: temporarily relaxes `set -eEuo pipefail` and traps while running the asserted command, then restores them.

---

## Quick Start

```bash
#!/bin/bash
source /usr/local/lib_bash/lib_bash.sh   # brings in colors, helpers, and lib_assert

ok_cmd()   { echo "hello"; }
fail_cmd() { return 42; }

assert_equal      "ok_cmd"          "hello"     # passes
assert_contains   "ok_cmd"          "ell"       # passes
assert_return_code "fail_cmd"        42          # passes
assert_pass       "ok_cmd"                       # passes (rc 0)
assert_fail       "fail_cmd"                     # passes (non‑zero rc)

# Intentionally failing examples
assert_equal      "ok_cmd"          "nope"
assert_contains   "ok_cmd"          "zzz"
assert_return_code "fail_cmd"        1
```

Example failure output (colors stripped):

```
*** ASSERT assert_equal FAILED ***
File     : /path/to/your_script.sh
Test     : ok_cmd
Result   : "hello"
Expected : "nope"
```

More failure examples (colors stripped):

assert_contains failure
```
*** ASSERT assert_contains FAILED ***
File     : /path/to/your_script.sh
Test     : ok_cmd
Result   : "hello"
Expected : "*zzz*"
```

assert_return_code failure
```
*** ASSERT assert_return_code FAILED ***
File     : /path/to/your_script.sh
Test     : fail_cmd
Result   : return code = 42
Expected : return code = 1
```

Unknown command
```
*** ASSERT check_assert_command_defined FAILED ***
File     : /path/to/your_script.sh
Test     : no_such_fn
Result   : command "no_such_fn" is not a declared function or a valid internal or external command 
Expected : return code = 0
```

---

## Features

- Simple assertions for strings and return codes
- Substring containment check with `assert_contains`
- Clear, consistent failure message format
- Detects unknown commands before execution and reports them
- Does not exit on failure; you can aggregate results in your own harness

---

## API Summary

| Function | Description |
|---------|-------------|
| `assert_equal <cmd> <expected>` | Run `cmd`, compare its stdout with `expected` (exact match). |
| `assert_contains <cmd> <needle>` | Run `cmd`, check if stdout contains `needle` (substring). |
| `assert_return_code <cmd> <rc>` | Run `cmd`, compare its numeric exit code with `rc`. |
| `assert_pass <cmd>` | Pass if `cmd` returns 0. |
| `assert_fail <cmd>` | Pass if `cmd` returns non‑zero. |
| `assert_debug_message <True|False> <message>` | Print a formatted debug block when first arg is `True`. |

Helper functions (internal):

- `get_result_as_string <cmd>` – Echo stdout of `cmd` (with shell state restored afterward).
- `get_returncode_as_string <cmd>` – Echo exit code of `cmd` as a string.
- `check_assert_command_defined <cmd>` – Emits a failure banner if the command/function is not valid.

---

## Notes and Behavior

- Shell state safety: both `get_result_as_string` and `get_returncode_as_string` save current shell options and `ERR` trap, disable `-eEuo pipefail` and the trap for the duration of the call, then restore them. This prevents the asserted command’s behavior from interfering with your script’s strict mode.
- Unknown commands: if the function/command in `<cmd>` is not found, a failure banner is printed and `get_returncode_as_string` returns `"127"`, while `get_result_as_string` returns an empty string. This mirrors conventional shell semantics (`127` for command not found).
- Non‑terminating: assertions print failures but do not exit. If you need a failing exit code for CI, collect failures in a counter and exit accordingly.

---

## Examples

Exact match:
```bash
assert_equal "echo foo" "foo"
```

Contains substring:
```bash
assert_contains "printf 'abc def'" "bc d"
```

Return code checks:
```bash
assert_return_code "grep nope /etc/passwd" 2   # grep returns 2 on some errors
assert_pass       "true"
assert_fail       "false"
```


Debug message:
```bash
assert_debug_message True "About to run expensive test"
```

Sample debug block (colors stripped):
```
** DEBUG *****************************************************************************************************
File          : /path/to/your_script.sh
Function      : your_test_fn
Caller        : main
Debug Message : About to run expensive test
**************************************************************************************************************
```

---

## Requirements

- Bash 4.0+
- Part of `lib_bash`; source `lib_bash.sh` to get colors and helper utilities (`clr_*`, `get_script_fullpath`, `is_valid_command`).

---

## License

GNU General Public License v3.0 – See LICENSE for details.

---

## Contributing

1. Fork the repository  
2. Create a feature branch  
3. Commit your changes  
4. Submit a Pull Request
