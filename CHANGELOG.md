# Changelog

## 1.0.1 (2025-08-29)

### Changed
- lib_retry: switched option parsing from external `getopt` to built-in `getopts` (no external dependency).
- lib_retry: moved dependency check inside `retry`; added safe stderr fallback logger; preserved caller `-e` state.
- lib_retry: documented getopts usage and logger fallback; clarified requirements.
- lib_bash_log: fixed `logc`/`logc_err` to capture correct exit codes with `pipefail`, preserving caller flags.
- docs: updated default log paths to use `${XDG_STATE_HOME:-$HOME/.local/state}` for user logs; clarified `<script>` naming via `get_script_stem()`.
- docs/tests: added descriptive headers to scripts and tests; minor comment improvements.

### Fixed
- tests: `test_lib_bash_log.sh` expectations for `logc`/`logc_err` now pass with corrected exit codes.
- shellcheck: removed inline function definition to avoid SC2317; adjusted test shellcheck header to avoid directive parsing.

### Tests
- All suites pass via `.tests/run_all_tests.sh` (logging, tempfiles, color, retry).

## 1.0.0 (2025-08-28)

### Added
- docs: README_lib_assert.md with usage, API, failures, and debug examples
- README: Assertions section linking to lib_assert docs

### Fixed
- lib_assert: correct failure message variable; include assert function name
- lib_assert: fix default expansion, restore shell opts and ERR trap around evals
- lib_assert: handle unknown commands (127) and return empty output consistently
- lib_bash.sh: case pattern fix — '?' literal only in help arm

### Tests
- All suites pass via .tests/run_all_tests.sh
- ShellCheck warnings silenced where appropriate (SC2015, SC2154, SC2034)
