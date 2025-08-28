# Changelog

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
