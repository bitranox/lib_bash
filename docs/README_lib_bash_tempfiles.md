# lib_bash_tempfiles.sh – Temporary Paths Management for Bash

![License: GPLv3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Part of lib_bash](https://img.shields.io/badge/Part%20of-lib__bash-ffdd00.svg)

Part of the [lib_bash](https://github.com/bitranox/lib_bash) collection – a utility suite for professional Bash scripting.

---

## Overview

This module provides a small, robust API to create, register, list, and clean up temporary files and directories. All temporary paths are stored in a single registry file (one path per line), allowing a unified cleanup step at the end of your script or session.

- Single registry file; print its location via `print_temppath_registry`.
- Create via `create_temp_file` / `create_temp_dir` (auto-registered).
- Register any existing path via `register_temppath`.
- Cleanup in two passes: files first, then empty directories.
- Inspect failures via the arrays `_TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_FILES` and `_TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_DIRS`.

---

## Quick Start

```bash
#!/bin/bash
source /usr/local/lib_bash/lib_bash.sh   # sources tempfiles module

# Create temporary resources (auto-registered)
f=$(create_temp_file)           # e.g. /tmp/tmpfile.xxxxxx
d=$(create_temp_dir)            # e.g. /tmp/tmpdir.xxxxxx

echo "hello" >"$f"
mkdir -p "$d/sub"

# Register an additional existing path (optional)
register_temppath "/some/other/path"

# List and inspect
list_temppaths
echo "Registry: $(print_temppath_registry)"

# Clean up on exit
trap 'cleanup_temppaths' EXIT
```

Portable mktemp behavior: if you don’t pass a template, the module uses `${TMPDIR:-/tmp}/tmpfile.XXXXXXXX` and `${TMPDIR:-/tmp}/tmpdir.XXXXXXXX` under the hood.

---

## Features

- Single registry file (under `${TMPDIR:-/tmp}`) used for all entries
- Deduplication when registering paths
- Two-pass cleanup with warnings logged for failures
- Failure arrays to inspect what could not be removed
- Portable mktemp usage (Linux, macOS/BSD compatible)
- Bash 3.2+ compatible

---

## API Summary

| Function | Description |
|---------|-------------|
| `create_temp_file [template]` | Create a temp file, register it, print the path. If `template` is provided, it must end with at least six `X` characters. |
| `create_temp_dir [template]` | Create a temp directory, register it, print the path. Same template rule as above. |
| `register_temppath <path>` | Add a path (file or directory) to the registry (deduplicated). |
| `unregister_temppath <path>` | Remove a specific path from the registry (returns 0 on removal, 1 if not found). |
| `list_temppaths` | Print all currently registered paths (raw, one per line). |
| `print_temppath_registry` | Print the registry file path. |
| `clear_temppath_registry` | Truncate the registry file (remove all entries, keep the file). |
| `cleanup_temppaths` | Delete all files, then attempt to remove empty directories; clear registry; return 0 if all gone, 1 on any failure. |

Internal/helper:

- `_get_number_of_registered_paths` – Print count of lines in registry.
- Failure arrays:
  - `_TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_FILES`
  - `_TMP_LIB_BASH_TEMPFILES_CLEANUP_FAILED_DIRS`

---

## Examples

### 1) Simple lifecycle

```bash
f=$(create_temp_file)
echo "data" >"$f"
cleanup_temppaths
```

### 2) With trap on EXIT

```bash
#!/bin/bash
source /usr/local/lib_bash/lib_bash.sh
set -Eeuo pipefail
trap 'cleanup_temppaths' EXIT

d=$(create_temp_dir)
do_work_that_uses "$d"
# On script exit, files are deleted first; then empty dirs are removed.
```

### 3) Custom template

```bash
f=$(create_temp_file "${TMPDIR:-/tmp}/myapp.XXXXXXXX")
d=$(create_temp_dir  "${TMPDIR:-/tmp}/myappdir.XXXXXXXX")
```

> Note: Templates must end with at least six `X` characters.

---

## Portability Notes

- Uses portable `mktemp` patterns (no GNU-specific `-t`).
- Avoids Bash 4-only `declare -g`; compatible with Bash 3.2+.
- Uses BSD-safe `rmdir` (no `--`).
- Canonicalization prefers `realpath`, falls back to `readlink -f` when available, else uses the original path.

---

## Requirements

- Bash 3.2+
- Standard UNIX tools: `mktemp`, `rm`, `rmdir`, `find`.
- Optional: `realpath` or `readlink` for better canonicalization.

---

## License

GNU General Public License v3.0 – See [LICENSE](https://github.com/bitranox/lib_bash/blob/master/docs/LICENSE) for details.

---

## Contributing

1. Fork the repository  
2. Create a feature branch  
3. Commit your changes  
4. Submit a Pull Request

See [CONTRIBUTING.md](https://github.com/bitranox/lib_bash/blob/master/docs/CONTRIBUTING.md) for more details.

---

Tested on Linux and macOS. Part of the [lib_bash](https://github.com/bitranox/lib_bash) professional scripting toolkit.

