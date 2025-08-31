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

release: ## Interactive: prompts version, updates changelog, commits, branches, tags (with notes), pushes, and creates GitHub Release
	@set -Eeuo pipefail; IFS=$$'\n\t'; \
	current=$$(awk '/^##[[:space:]]+v?[0-9]+\.[0-9]+\.[0-9]+([[:space:]]|\()/{ver=$$2; sub(/^v/,"",ver); print ver; exit}' CHANGELOG.md); \
	echo "Current version: $${current:-<none>}"; \
	read -rp "Enter new version (SemVer X.Y.Z): " newv; \
	[ -n "$$newv" ] || { echo "ERROR: Version is required" >&2; exit 1; }; \
	printf "%s" "$$newv" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "ERROR: Invalid SemVer: $$newv" >&2; exit 1; }; \
	branch_cur=$$(git rev-parse --abbrev-ref HEAD); \
	[ "$$branch_cur" = "$(RELEASE_BRANCH)" ] || { echo "ERROR: Switch to branch $(RELEASE_BRANCH) (current: $$branch_cur)" >&2; exit 1; }; \
	[ -z "$$({ git status --porcelain || true; } | sed -n '1p')" ] || { echo "ERROR: Working tree not clean" >&2; git status --porcelain; exit 1; }; \
	git fetch -q; \
	[ "$$(git rev-parse HEAD)" = "$$({ git rev-parse origin/$(RELEASE_BRANCH) || echo unknown; })" ] || { echo "ERROR: Local $(RELEASE_BRANCH) not up to date with origin" >&2; exit 1; }; \
	! git rev-parse -q --verify "refs/tags/v$$newv" >/dev/null || { echo "ERROR: Tag v$$newv already exists" >&2; exit 1; }; \
	read -rp "One-line release notes (optional): " notes || true; \
	date_str=$$(date +%Y-%m-%d); \
	tmp=$$(mktemp); \
	awk -v ver="$$newv" -v d="$$date_str" -v msg="$$notes" 'NR==1{print; print ""; print "## " ver " (" d ")"; print ""; print "### Changed"; if (length(msg)) print "- " msg; else print "- See details in this release."; next}1' CHANGELOG.md > "$$tmp"; \
	mv "$$tmp" CHANGELOG.md; \
	branch_name="release/v$$newv"; \
	git checkout -b "$$branch_name"; \
	git add CHANGELOG.md; \
	commit_msg="release: v$$newv"; [ -n "$$notes" ] && commit_msg="$$commit_msg — $$notes"; \
	git commit -m "$$commit_msg"; \
	git push -u origin "$$branch_name"; \
	# Prepare release notes body from the new CHANGELOG section (match header with or without leading v)
	body=$$(awk '/^##[[:space:]]+v?'"$$newv"'([[:space:]]|\()/{flag=1;next}/^##[[:space:]]/{flag=0}flag' CHANGELOG.md); [ -n "$$body" ] || body="See CHANGELOG.md for $$newv details."; \
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
	echo "Release v$$newv complete on branch $$branch_name"
