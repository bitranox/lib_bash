# Changelog

## 1.0.7 (2025-08-31)

### Changed
- Makefile: unify release flow; use explicit SHA for create; omit target on edit

## 1.0.6 (2025-08-31)

### Fixed
- lib_bash: `_set_askpass` now tolerates missing `ssh-askpass`, avoiding noisy `ERR ... command -v ssh-askpass` under strict mode.

### Tests
- `make ci` green locally after the fix.

## 1.0.5 (2025-08-29)

### Changed
- Makefile: fix GitHub Release target commitish handling — use explicit commit SHA on create and omit `--target` on edit to avoid `Release.target_commitish is invalid`.
- Docs: minor `AGENTS.md` heading fix.

## 1.0.4 (2025-08-29)

### Changed
- Makefile: release target now requires `gh` and creates/updates the GitHub Release in one step (bundled with tagging/push).
- Removed separate `release-notes` target; use `make release VERSION=X.Y.Z` for notes publishing from `CHANGELOG.md`.

### Tests
- Pre-release checks pass via `make pre-release VERSION=1.0.4`.

## 1.0.3 (2025-08-29)

### Changed
- Makefile: always create a GitHub Release entry during `make release`.
- Makefile: prefer `GH_TOKEN`/`GITHUB_TOKEN` env vars for GitHub API auth; fallback to token in remote URL only if env tokens are missing.

### Tests
- Pre-release checks (`make pre-release VERSION=1.0.3`) pass locally.

## 1.0.2 (2025-08-29)

### Added
- Makefile with `help`, `lint`, `test`, `ci`, `pre-release`, and `release` targets
- AGENTS.md guiding Codex/humans to use Make targets

### Changed
- Release workflow: added enforced pre-release checks (SemVer, clean tree, branch, up-to-date, changelog section)

### Tests
- `make ci` runs lint + tests; all suites passing

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
