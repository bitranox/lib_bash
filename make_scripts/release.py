#!/usr/bin/env python3
from __future__ import annotations

import os
import re
import shlex
import shutil
import subprocess as sp
import sys
import tempfile
from datetime import date
from pathlib import Path


def run(cmd: list[str], check: bool = True, capture: bool = False, cwd: str | None = None) -> str:
    if capture:
        out = sp.run(cmd, check=check, stdout=sp.PIPE, stderr=sp.STDOUT, text=True, cwd=cwd)
        return out.stdout.strip()
    else:
        sp.run(cmd, check=check, cwd=cwd)
        return ""


def ensure_deps() -> None:
    for dep in ("git", "gh"):
        if shutil.which(dep) is None:
            sys.exit(f"Missing dependency: {dep}. Please install it.")


def ensure_repo_state() -> None:
    branch = os.environ.get("RELEASE_BRANCH", "master")

    cur_branch = run(["git", "rev-parse", "--abbrev-ref", "HEAD"], capture=True)
    if cur_branch != branch:
        sys.exit(f"You are on '{cur_branch}'. Switch to '{branch}' to release (set RELEASE_BRANCH to override).")

    # If upstream exists, fetch and ensure not behind; fast-forward if only behind
    upstream_ok = True
    try:
        run(["git", "rev-parse", "--verify", "--quiet", "@{u}"])
    except sp.CalledProcessError:
        upstream_ok = False

    if upstream_ok:
        # fetch quietly
        try:
            run(["git", "fetch", "-p", "origin"], check=False)
        except Exception:
            pass

        counts = run(["git", "rev-list", "--left-right", "--count", "@{u}...HEAD"], capture=True)
        behind, ahead = [int(x) for x in counts.split()]
        if behind > 0 and ahead == 0:
            print(f"Branch is behind origin by {behind} commit(s). Attempting fast-forward...")
            run(["git", "pull", "--ff-only"])
            counts = run(["git", "rev-list", "--left-right", "--count", "@{u}...HEAD"], capture=True)
            behind, ahead = [int(x) for x in counts.split()]
        if behind > 0:
            sys.exit("Local branch is behind remote. Please pull/reconcile before releasing.")


def get_current_version() -> str:
    try:
        tag = run(["git", "describe", "--tags", "--abbrev=0"], capture=True)
        return tag[1:] if tag.startswith("v") else tag
    except sp.CalledProcessError:
        pass
    # Fallback to CHANGELOG
    ch = Path("CHANGELOG.md")
    if ch.exists():
        for line in ch.read_text(encoding="utf-8").splitlines():
            m = re.match(r"^##\s+(\d+\.\d+\.\d+)\b", line)
            if m:
                return m.group(1)
    return "0.0.0"


SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


def validate_version(v: str) -> str:
    if not SEMVER_RE.match(v):
        sys.exit(f"Invalid VERSION '{v}'. Expected SemVer: X.Y.Z")
    return v


def choose_bump() -> str:
    bump = os.environ.get("BUMP", "").strip()
    if not bump:
        if sys.stdin.isatty() and sys.stdout.isatty():
            print("Select version bump: [m]ajor / mi[n]or / [p]atch (default)")
            try:
                ans = input("> ").strip().lower()
            except EOFError:
                ans = ""
            if ans in ("m", "major"):
                bump = "major"
            elif ans in ("n", "minor"):
                bump = "minor"
            elif ans in ("", "p", "patch"):
                bump = "patch"
            else:
                sys.exit(f"Unknown choice '{ans}'")
        else:
            bump = "patch"
    if bump not in ("major", "minor", "patch"):
        sys.exit("BUMP must be one of: major, minor, patch")
    return bump


def bump_version(cur: str, bump: str) -> str:
    m = SEMVER_RE.match(cur)
    if not m:
        sys.exit(f"Cannot parse current version '{cur}' as SemVer")
    major, minor, patch = map(int, m.groups())
    if bump == "major":
        major += 1
        minor = 0
        patch = 0
    elif bump == "minor":
        minor += 1
        patch = 0
    else:
        patch += 1
    return f"{major}.{minor}.{patch}"


def has_changes() -> bool:
    # unstaged
    unstaged = sp.run(["git", "diff", "--quiet"]).returncode != 0
    # staged
    staged = sp.run(["git", "diff", "--cached", "--quiet"]).returncode != 0
    return unstaged or staged


def commit_all_changes(msg: str) -> None:
    if has_changes():
        run(["git", "add", "-A"])
        run(["git", "commit", "-m", msg])


def collect_notes_since_last_tag() -> list[str]:
    try:
        last_tag = run(["git", "describe", "--tags", "--abbrev=0"], capture=True)
        rng = f"{last_tag}..HEAD"
    except sp.CalledProcessError:
        first = run(["git", "rev-list", "--max-parents=0", "HEAD"], capture=True)
        rng = f"{first}..HEAD"

    log = run(["git", "log", "--no-merges", "--pretty=format:%s", rng], capture=True)
    messages = [m for m in log.splitlines() if m.strip()]

    # Exclude maintenance entries:
    # - Any chore:* or chore(scope):* commit messages
    # - docs(changelog):* maintenance
    # - Merge commits (already removed via --no-merges, keep guard for PR merges)
    exclude = re.compile(r"^(Merge( pull request)?|chore(\(|:)|docs\(changelog\))", re.IGNORECASE)
    notes = [f"- {m}" for m in messages if not exclude.match(m)]
    if not notes:
        notes = ["- No changes recorded since last version."]
    return notes


def update_changelog(new_version: str) -> None:
    notes = collect_notes_since_last_tag()
    today = date.today().isoformat()

    header = [f"## {new_version} ({today})", "", "### Changed"]
    content_lines = ["# Changelog", "", *header, *notes, "",]

    ch_path = Path("CHANGELOG.md")
    if ch_path.exists():
        old = ch_path.read_text(encoding="utf-8").splitlines()
        # drop existing main header line if present
        if old and old[0].lstrip().startswith("# Changelog"):
            old = old[1:]
            # drop a single leading blank line
            if old and old[0].strip() == "":
                old = old[1:]
        content_lines.extend(old)
    ch_path.write_text("\n".join(content_lines) + "\n", encoding="utf-8")


def extract_release_notes(version: str) -> str:
    ch = Path("CHANGELOG.md").read_text(encoding="utf-8").splitlines()
    out: list[str] = []
    in_section = False
    for line in ch:
        if line.startswith("## "):
            if in_section:
                break
            in_section = line.startswith(f"## {version} ") or line.strip() == f"## {version}"
            continue
        if in_section:
            out.append(line)
    return "\n".join(out).strip()


def push_branch() -> None:
    # check upstream
    try:
        run(["git", "rev-parse", "--verify", "--quiet", "@{u}"])
        run(["git", "push"])
    except sp.CalledProcessError:
        run(["git", "push", "-u", "origin", "HEAD"])


def upsert_github_release(version: str) -> None:
    tag = f"v{version}"
    notes = extract_release_notes(version) or f"Release {version}"
    # Use a temporary file to avoid quoting issues
    with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8") as tf:
        tf.write(notes)
        tf.flush()
        path = tf.name
    try:
        exists = sp.run(["gh", "release", "view", tag], stdout=sp.DEVNULL, stderr=sp.DEVNULL).returncode == 0
        if exists:
            run(["gh", "release", "edit", tag, "--title", tag, "--notes-file", path])
        else:
            run(["gh", "release", "create", tag, "--title", tag, "--notes-file", path])
    finally:
        try:
            Path(path).unlink(missing_ok=True)
        except Exception:
            pass


def main() -> None:
    ensure_deps()
    ensure_repo_state()

    current_version = get_current_version()

    env_version = os.environ.get("VERSION", "").strip()
    if env_version:
        new_version = validate_version(env_version)
    else:
        bump = choose_bump()
        new_version = bump_version(current_version, bump)

    print(f"Current version: {current_version}")
    print(f"New version:     {new_version}")

    # Commit any outstanding changes before generating changelog
    commit_all_changes(f"chore: prepare release v{new_version}")

    # Update changelog and commit it
    update_changelog(new_version)
    run(["git", "add", "CHANGELOG.md"])
    run(["git", "commit", "-m", f"docs(changelog): {new_version}"])

    # Push branch before tagging
    push_branch()

    # Tag and push tag
    tag = f"v{new_version}"
    # Fail clearly if tag already exists
    existing_tags = run(["git", "tag", "--list", tag], capture=True)
    if existing_tags.strip() == tag:
        sys.exit(f"Tag '{tag}' already exists.")
    run(["git", "tag", "-a", tag, "-m", tag])
    run(["git", "push", "--follow-tags", "origin", "HEAD"]) 

    # Create or update GitHub release
    upsert_github_release(new_version)
    print(f"Release v{new_version} completed.")


if __name__ == "__main__":
    try:
        main()
    except sp.CalledProcessError as e:
        cmd = " ".join(shlex.quote(c) for c in e.cmd) if isinstance(e.cmd, (list, tuple)) else str(e.cmd)
        sys.stderr.write(f"Command failed: {cmd}\n")
        sys.exit(e.returncode or 1)
