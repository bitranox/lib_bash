Preferred Commands for Codex (and humans)

Use the Makefile targets from the repository root:

- make help
  - Lists available targets and descriptions

- make lint
  - Runs ShellCheck over test scripts and top-level scripts

- make test
  - Runs the full test suite (`.tests/run_all_tests.sh`)

- make ci
  - Runs `lint` then `test`

Notes
- Always run these from the repository root.
- Tests and lint write to `/tmp` and expect a POSIX environment.
