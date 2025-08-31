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

- make release
  - Commits all current changes
  - Shows current version and prompts for new version (blank = bump patch)
  - Updates `CHANGELOG.md` with a new section built from commits since the last tag
  - Commits the changelog update, pushes branch, then tags the release so the tag includes the new changelog entry
  - Fails if the new changelog section for the version cannot be extracted (no silent fallback)
  - Creates/updates the GitHub Release (requires `gh`), pulling notes from that new changelog section
  - Optional: `VERSION=X.Y.Z` to skip prompt; `BUMP=major|minor|patch` to auto-compute; `SKIP_CI=1` to bypass `make ci`

Notes
- Always run these from the repository root.
- Tests and lint write to `/tmp` and expect a POSIX environment.
