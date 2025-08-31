SHELL := bash
.ONESHELL:
.DEFAULT_GOAL := help

##
## lib_bash project helper targets
##

.PHONY: help lint test ci release
# Branch on which releases are allowed
RELEASE_BRANCH ?= master

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_.-]+:.*##/ {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

lint: ## Run shellcheck on tests and top-level scripts
	@cd .tests && ./shellcheck.sh

test: ## Run the full test suite
	@cd .tests && ./run_all_tests.sh

ci: ## Run lint and tests
	@$(MAKE) lint
	@$(MAKE) test

release: ## Interactive: commit changes, prompt/auto-bump version, update CHANGELOG from git log, tag, push, and create GitHub Release
	@set -Eeuo pipefail; IFS=$$'\n\t'; \
	branch_cur=$$(git rev-parse --abbrev-ref HEAD); \
	[ "$$branch_cur" = "$(RELEASE_BRANCH)" ] || { echo "ERROR: Switch to branch $(RELEASE_BRANCH) (current: $$branch_cur)" >&2; exit 1; }; \
	git fetch -q || true; \
	# Ensure local is not behind remote to avoid merges during release
	if git rev-parse --verify -q origin/"$(RELEASE_BRANCH)" >/dev/null; then \
		if ! git merge-base --is-ancestor origin/"$(RELEASE_BRANCH)" HEAD; then \
			echo "ERROR: Local branch is behind origin/$(RELEASE_BRANCH). Please pull/rebase first." >&2; exit 1; \
		fi; \
	else \
		echo "ERROR: Remote branch origin/$(RELEASE_BRANCH) not found. Add remote or fetch." >&2; exit 1; \
	fi; \
	# Commit all current changes if any
	if [ -n "$$({ git status --porcelain || true; } | sed -n '1p')" ]; then \
		git add -A; \
		git commit -m "chore: commit all changes before release"; \
	fi; \
	# Determine current version from CHANGELOG.md (first version header)
	current=$$(awk '/^##[[:space:]]+v?[0-9]+\.[0-9]+\.[0-9]+/{ver=$$2; sub(/^v/,"",ver); print ver; exit}' CHANGELOG.md); \
	echo "Current version: $${current:-<none>}"; \
	# Determine new version: VERSION > BUMP > prompt (blank => patch)
	newv="$${VERSION:-}"; \
	if [ -z "$$newv" ] && [ -n "$${BUMP:-}" ]; then \
		case "$$BUMP" in major|minor|patch) ;; *) echo "ERROR: Invalid BUMP='$$BUMP' (use major|minor|patch)" >&2; exit 1;; esac; \
		if [ -n "$$current" ]; then IFS=. read -r a b c <<<"$$current"; case "$$BUMP" in major) a=$$((a+1)); b=0; c=0 ;; minor) b=$$((b+1)); c=0 ;; patch) c=$$((c+1)) ;; esac; newv="$$a.$$b.$$c"; else echo "ERROR: No current version found; please specify VERSION=X.Y.Z when using BUMP" >&2; exit 1; fi; \
	fi; \
	if [ -z "$$newv" ]; then read -rp "Enter new version (SemVer X.Y.Z, blank = patch bump): " ans || true; newv="$$ans"; fi; \
	if [ -z "$$newv" ]; then \
		if [ -n "$$current" ]; then IFS=. read -r a b c <<<"$$current"; c=$$((c+1)); newv="$$a.$$b.$$c"; else echo "ERROR: No current version found; please specify VERSION=X.Y.Z" >&2; exit 1; fi; \
	fi; \
	printf "%s" "$$newv" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "ERROR: Invalid SemVer: $$newv" >&2; exit 1; }; \
	! git rev-parse -q --verify "refs/tags/v$$newv" >/dev/null || { echo "ERROR: Tag v$$newv already exists" >&2; exit 1; }; \
	# Build CHANGELOG entry using commit messages since last tag/current version
	date_str=$$(date +%Y-%m-%d); \
	prev_tag=""; if [ -n "$$current" ] && git rev-parse -q --verify "refs/tags/v$$current" >/dev/null; then prev_tag="v$$current"; fi; \
	log_range=""; [ -n "$$prev_tag" ] && log_range="$$prev_tag..HEAD" || log_range=""; \
	changes=$$(git log --no-merges --pretty='- %s' $$log_range | grep -Ev '^(release: v[0-9]+\.[0-9]+\.[0-9]+|chore: commit all changes before release)$$' || true); \
	[ -n "$$changes" ] || changes="- No changes recorded since last version."; \
	tmp=$$(mktemp); \
	awk -v ver="$$newv" -v d="$$date_str" -v body="$$changes" 'NR==1{print; print ""; print "## " ver " (" d ")"; print ""; print "### Changed"; print body; next}1' CHANGELOG.md > "$$tmp"; \
	mv "$$tmp" CHANGELOG.md; \
	git add -A; \
	git commit -m "release: v$$newv"; \
	# Optional CI gate (set SKIP_CI=1 to bypass)
	[ "${SKIP_CI:-}" = 1 ] || $(MAKE) ci; \
	# Push branch with the changelog commit so the tag includes the new section
	git push origin HEAD:"$(RELEASE_BRANCH)"; \
	# Prepare release notes body by extracting the new section from CHANGELOG.md
	body=$$(awk -v ver="$$newv" 'f==1 && /^## /{exit} f{print} ($$1=="##" && $$2==ver){f=1; next}' CHANGELOG.md); [ -n "$$body" ] || body="See CHANGELOG.md for $$newv details."; \
	# Create annotated tag including the release notes
	git tag -a "v$$newv" -m "lib_bash $$newv" -m "$$body"; \
	git push origin "v$$newv"; \
	command -v gh >/dev/null 2>&1 || { echo "ERROR: gh CLI is required. Install gh and run: gh auth login" >&2; exit 1; }; \
	sha=$$(git rev-parse HEAD); \
	if gh release view "v$$newv" >/dev/null 2>&1; then \
		gh release edit "v$$newv" --title "lib_bash $$newv" --notes "$$body"; \
	else \
		gh release create "v$$newv" --title "lib_bash $$newv" --notes "$$body" --target "$$sha"; \
	fi; \
	echo "Release v$$newv complete on branch $(RELEASE_BRANCH)"
