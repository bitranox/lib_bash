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

- make pre-release VERSION=X.Y.Z
  - Verifies SemVer format, runs `lint` and `test`, ensures you are on `RELEASE_BRANCH` (default: `master`) and the working tree is clean, checks the branch is up to date with `origin/RELEASE_BRANCH`, checks `CHANGELOG.md` has a section for the version, and verifies the tag does not already exist

- make release VERSION=X.Y.Z
  - Runs `pre-release` checks, tags `vX.Y.Z`, pushes branch and tag
  - Creates or updates the GitHub Release (requires `gh` and pulls notes from `CHANGELOG.md`)

Notes
- Always run these from the repository root.
- Tests and lint write to `/tmp` and expect a POSIX environment.
- For release notes, update `CHANGELOG.md` before invoking `make release VERSION=...`.
