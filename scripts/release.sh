#!/usr/bin/env bash
set -euo pipefail

# make release helper
# - Asks for version bump (major/minor/patch) unless BUMP or VERSION is provided
# - Updates CHANGELOG.md by prepending a new section with commits since last tag
# - Commits and pushes all changes
# - Creates or updates a GitHub Release using `gh` with notes from the changelog

main() {
  ensure_deps
  ensure_repo_state

  local current_version new_version bump
  current_version=$(get_current_version)

  if [[ ${VERSION:-} ]]; then
    new_version=$(validate_version "$VERSION")
  else
    bump=$(choose_bump)
    new_version=$(bump_version "$current_version" "$bump")
  fi

  echo "Current version: ${current_version}"
  echo "New version:     ${new_version}"

  # Commit any outstanding changes before generating changelog
  commit_all_changes "chore: prepare release v${new_version}"

  # Update changelog with commits since last tag
  update_changelog "$new_version"

  # Commit the changelog update
  git add CHANGELOG.md
  git commit -m "docs(changelog): ${new_version}"

  # Push branch before tagging to ensure tag contains the changelog commit in history
  push_branch

  # Tag and push tag
  git tag -a "v${new_version}" -m "v${new_version}"
  git push --follow-tags origin HEAD

  # Create or update GitHub release with notes from the changelog section
  upsert_github_release "$new_version"

  echo "Release v${new_version} completed."
}

ensure_deps() {
  command -v git >/dev/null 2>&1 || { echo "git not found" >&2; exit 1; }
  command -v gh >/dev/null 2>&1 || { echo "gh (GitHub CLI) not found. Please install and authenticate (gh auth login)." >&2; exit 1; }
}

ensure_repo_state() {
  local branch=${RELEASE_BRANCH:-master}
  # Ensure on correct branch
  local cur_branch
  cur_branch=$(git rev-parse --abbrev-ref HEAD)
  if [[ "$cur_branch" != "$branch" ]]; then
    echo "You are on '$cur_branch'. Switch to '$branch' to release (set RELEASE_BRANCH to override)." >&2
    exit 1
  fi

  # Make sure remote is reachable and we are not behind; if behind, attempt fast-forward
  if git rev-parse --verify --quiet "@{u}" >/dev/null; then
    git fetch -p origin >/dev/null 2>&1 || true
    local behind ahead
    behind=$(git rev-list --count --left-right @{u}...HEAD | awk '{print $1}')
    ahead=$(git rev-list --count --left-right @{u}...HEAD | awk '{print $2}')
    # If behind but not diverged, try fast-forward
    if [[ "$behind" -gt 0 && "$ahead" -eq 0 ]]; then
      echo "Branch is behind origin by $behind commit(s). Attempting fast-forward..."
      git pull --ff-only
    fi
    # Recompute after possible ff
    behind=$(git rev-list --count --left-right @{u}...HEAD | awk '{print $1}')
    if [[ "$behind" -gt 0 ]]; then
      echo "Local branch is behind remote. Please pull/reconcile before releasing." >&2
      exit 1
    fi
  fi
}

get_current_version() {
  # Prefer latest tag matching v* or semver; fallback to 0.0.0
  if tag=$(git describe --tags --abbrev=0 2>/dev/null); then
    echo "${tag#v}"
    return 0
  fi
  # Fallback: parse topmost version from CHANGELOG if present
  if [[ -f CHANGELOG.md ]]; then
    if ver=$(awk '/^## [0-9]+\.[0-9]+\.[0-9]+/ {gsub(/^## /,""); print $1; exit}' CHANGELOG.md); then
      [[ -n "$ver" ]] && { echo "$ver"; return 0; }
    fi
  fi
  echo "0.0.0"
}

validate_version() {
  local v=$1
  if [[ "$v" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "$v"
  else
    echo "Invalid VERSION '$v'. Expected SemVer: X.Y.Z" >&2
    exit 1
  fi
}

choose_bump() {
  local bump=${BUMP:-}
  if [[ -z "$bump" ]]; then
    echo "Select version bump: [m]ajor / mi[n]or / [p]atch (default)"
    read -r -p "> " ans || true
    case "${ans,,}" in
      m|major) bump=major ;;
      n|minor) bump=minor ;;
      ""|p|patch) bump=patch ;;
      *) echo "Unknown choice '$ans'" >&2; exit 1 ;;
    esac
  fi
  case "$bump" in
    major|minor|patch) echo "$bump" ;;
    *) echo "BUMP must be one of: major, minor, patch" >&2; exit 1 ;;
  esac
}

bump_version() {
  local cur=$1 bump=$2
  if [[ ! "$cur" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "Cannot parse current version '$cur' as SemVer" >&2
    exit 1
  fi
  local major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[2]} patch=${BASH_REMATCH[3]}
  case "$bump" in
    major) ((major+=1)); minor=0; patch=0 ;;
    minor) ((minor+=1)); patch=0 ;;
    patch) ((patch+=1)) ;;
  esac
  echo "${major}.${minor}.${patch}"
}

commit_all_changes() {
  local msg=$1
  # Stage all changes if any
  if ! git diff --quiet || ! git diff --cached --quiet; then
    git add -A
    git commit -m "$msg"
  fi
}

update_changelog() {
  local new_version=$1
  local date
  date=$(date +%Y-%m-%d)

  local last_tag_range=""
  if tag=$(git describe --tags --abbrev=0 2>/dev/null); then
    last_tag_range="${tag}..HEAD"
  else
    last_tag_range="--reverse $(git rev-list --max-parents=0 HEAD)..HEAD"
  fi

  # Collect commit messages since last tag, excluding merges and obvious release commits
  local notes
  notes=$(git log --no-merges --pretty=format:'- %s' ${last_tag_range} | \
          grep -v -E '^(Merge |Merge pull request|chore\(release\)|docs\(changelog\))' || true)
  if [[ -z "$notes" ]]; then
    notes="- No changes recorded since last version."
  fi

  local header="## ${new_version} (${date})"
  local body="\n### Changed\n${notes}\n"

  if [[ ! -f CHANGELOG.md ]]; then
    printf '# Changelog\n\n%s\n%s\n' "$header" "$body" > CHANGELOG.md
    return
  fi

  # Prepend the new section to the existing changelog
  tmp=$(mktemp)
  {
    printf '# Changelog\n\n'
    printf '%s\n%s\n' "$header" "$body"
    # Append existing content without the first line if it is the main header
    tail -n +2 CHANGELOG.md || true
  } > "$tmp"
  mv "$tmp" CHANGELOG.md
}

extract_release_notes() {
  # Extract notes for a specific version from CHANGELOG.md
  local version=$1
  awk -v ver="$version" '
    /^## / {
      if (found) exit;            # next section reached
      found = ($2 == ver); next;  # start after the matching header
    }
    found { print }
  ' CHANGELOG.md
}

upsert_github_release() {
  local version=$1
  local tag="v${version}"
  local notes
  notes=$(extract_release_notes "$version")
  notes=${notes:-"Release ${version}"}

  # Try to create; if exists, update
  if gh release view "$tag" >/dev/null 2>&1; then
    gh release edit "$tag" --title "$tag" --notes "$notes"
  else
    gh release create "$tag" --title "$tag" --notes "$notes"
  fi
}

push_branch() {
  # Push current branch; ensure upstream exists
  if ! git rev-parse --verify --quiet "@{u}" >/dev/null; then
    git push -u origin HEAD
  else
    git push
  fi
}

main "$@"
