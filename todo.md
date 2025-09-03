codex
Here’s a focused clean‑code review of the Bash libraries against bash_clean_code.md.

Summary

- Overall: Solid, readable libraries with clear headers, purpose/usage notes, good error-handling patterns, and strong test coverage.
- Structure and naming largely align with the spec; logging and tempfiles are well-factored; retry is clean and configurable.
- A few areas to tighten: function size/single responsibility (linux_update), minor duplication, side effects on import, portable dependencies, and small stylistic nits.

Strengths

- Header + Usage: Each lib opens with purpose and usage, improving discoverability.
- Strict Mode: Enabled only when executed, not when sourced; traps are consistent.
- Small Functions: Most helpers are short, single-responsibility (tempfiles, retry, color wrappers).
- Error Handling: Centralized logging helpers (log, log_err, logc, logc_err), clear messages, return codes respected.
- Config/Constants: Uppercase globals for log state and debug mode; defaults are initialized coherently.
- Tests: Makefile targets present; tests are deterministic and comprehensive; make ci runs lint then tests.
- Readability: Names are intention-revealing; comments explain why/what succinctly; quoting and $(...) are consistently used.

Notable Deviations & Suggestions

- Side Effects on Import
    - lib_bash_log.sh ends by calling _set_default_logfiles RESET etc. on load, which mutates global state as a side effect of source.
    - Consider: Re-init only if unset, or expose an explicit init_logging entry point and keep automatic init minimal. This reduces “hidden” coupling and surprises when sourcing.
- Duplication vs. Wrapping
    - Logging wrappers (log, log_ok, log_wrench, etc.) repeat a similar pattern. Readability is good, but it’s close to duplication.
    - Consider: A tiny mapper or a single wrapper with level/icon mapping to reduce repetition while keeping call-sites clear.
- Dependencies Explicitness
    - lib_update_caller.sh uses git and readlink -f; lib_bash.sh’s linux_update uses apt tools; send_email uses mutt.
    - Suggestion: lightweight needs git, needs mutt (or fallback to mailx/sendmail) at call sites; document platform expectation (GNU readlink).
- Magic Numbers/Strings
    - lib_retry.sh: max_backoff=300, default attempts/delay inline; send_email: retries=3, exponential backoff.
    - Suggestion: promote these into small named constants at the top of each file to avoid magic numbers and clarify intent.
- Portability vs. Scope
    - readlink -f (GNU) and Debian-specific apt* are fine if the scope is Debian/Ubuntu, but call it out in headers. For broader portability, gate usage or provide fallback.
- Eval in Test Helpers
    - lib_assert.sh uses eval to execute string commands. Acceptable for test harnesses; still worth noting as a controlled risk area (it’s contained within test code).
- Minor Style Nits
    - lib_bash_prepend_text_to_file uses echo to write user content; spec recommends printf for robustness.
    - Internal _log has many parameters (9). It’s internal and well-contained; a small struct/associative array would improve clarity but isn’t necessary.
    - ShellCheck: low-severity findings
    - SC1091 (info) for dynamic sources (expected in library layout).
    - SC2119 (info) about forwarding args to `create_temp_file` (benign as implemented).

Tests & Quality Gates

- make help/lint/test/ci: present and working.
- ShellCheck run in tests; consider linting the library files too (current Makefile lints tests and root scripts).
- All tests passed locally (logging, tempfiles, colors, retry), including error paths and edge cases.

Per‑File Highlights

- lib_bash.sh
    - Good: strict‑mode guard, submodule sourcing, path helpers, elevation, logging integration.
    - Watch: linux_update function size/concerns; send_email depends solely on mutt (consider documented fallback).
- lib_bash_log.sh
    - Good: clear separation of formatting vs I/O, good prefixing, NO_TTY option, debug gating, command wrappers preserve -e/pipefail.
    - Watch: init side effect on source; many near‑duplicate wrappers (acceptable for clarity).
- lib_bash_tempfiles.sh
    - Good: single registry file pattern, two‑pass cleanup, robust canonicalization, fallback loggers if not using main log lib.
    - Clean, focused, and well‑tested.
- lib_retry.sh
    - Good: small, explicit options, non‑retryable exit codes, safe logger fallback, preserves caller -e.
    - Consider constants for defaults/backoff cap.
- lib_color.sh
    - Good: clear API, wrappers, 256‑color support, dump function for manual inspection.
    - Uses readlink -f in other libs; here it’s pure helpers.
- lib_assert.sh
    - Good: preserves shell state, clear failure messages, helpful formatting.
    - eval is intentional; keep it strictly within test scope.

If you want, I can:

- Propose a minimal refactor plan to split linux_update into small helpers (no behavior changes).
- Add a Makefile target to shellcheck the library files as well.
- Draft a short “platform dependencies” note per file (git/readlink/mutt/apt) to make dependencies explicit.
- 