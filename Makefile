.DEFAULT_GOAL := help

##
## lib_bash project helper targets
##

.PHONY: help lint test ci pre-release release release-notes

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

pre-release: ## Validate VERSION (SemVer), run CI, verify clean git and changelog
	@[ -n "$(VERSION)" ] || (echo "ERROR: VERSION=X.Y.Z is required" >&2; exit 1)
	@echo "Checking VERSION format: $(VERSION)"
	@printf "%s" "$(VERSION)" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' \
		|| (echo "ERROR: VERSION must be SemVer: X.Y.Z" >&2; exit 1)
	@echo "Checking current branch is $(RELEASE_BRANCH)..."
	@[ "$$(git rev-parse --abbrev-ref HEAD)" = "$(RELEASE_BRANCH)" ] \
		|| (echo "ERROR: Release must be run on branch $(RELEASE_BRANCH)." >&2; exit 1)
	@echo "Running CI..."
	@$(MAKE) ci
	@echo "Checking git working tree is clean..."
	@[ -z "$$(git status --porcelain || true)" ] || (echo "ERROR: git working tree not clean. Commit or stash changes." >&2; git status --porcelain; exit 1)
	@echo "Checking branch is up to date with origin/$(RELEASE_BRANCH)..."
	@git fetch -q
	@[ "$$(git rev-parse HEAD)" = "$$(git rev-parse origin/$(RELEASE_BRANCH))" ] \
		|| (echo "ERROR: Local branch not up to date with origin/$(RELEASE_BRANCH)." >&2; exit 1)
	@echo "Checking tag v$(VERSION) does not already exist..."
	@! git rev-parse -q --verify "refs/tags/v$(VERSION)" >/dev/null \
		|| (echo "ERROR: tag v$(VERSION) already exists." >&2; exit 1)
	@echo "Checking CHANGELOG.md contains version section..."
	@grep -Eq "^##[[:space:]]+v?$(VERSION)\b" CHANGELOG.md \
		|| (echo "ERROR: CHANGELOG.md missing section for $(VERSION)." >&2; exit 1)
	@echo "Pre-release checks passed."


release: pre-release ## Cut a release: make release VERSION=X.Y.Z
	@echo "Tagging and pushing v$(VERSION)..."
	@git tag -a v$(VERSION) -m "lib_bash $(VERSION)" -m "See CHANGELOG.md for details."
	@git push origin HEAD
	@git push origin v$(VERSION)
	@# Create or update GitHub Release via gh
	@command -v gh >/dev/null 2>&1 || (echo "ERROR: gh CLI is required. Install gh and run: gh auth login" >&2; exit 1)
	@echo "Creating/updating GitHub Release v$(VERSION) via gh..."
	@body="$$(awk '/^##  *v?$(VERSION)/{flag=1;next}/^##  /{flag=0}flag' CHANGELOG.md)"; [ -n "$$body" ] || body="See CHANGELOG.md for $(VERSION) details."
	@if gh release view v$(VERSION) >/dev/null 2>&1; then 		gh release edit v$(VERSION) --title "lib_bash $(VERSION)" --notes "$$body" --target HEAD; 	else 		gh release create v$(VERSION) --title "lib_bash $(VERSION)" --notes "$$body" --target HEAD; 	fi

release-notes: ## Create/update GitHub Release notes for existing tag: make release-notes VERSION=X.Y.Z
	@[ -n "$(VERSION)" ] || (echo "ERROR: VERSION=X.Y.Z is required" >&2; exit 1)
	@echo "Ensuring tag v$(VERSION) exists..."
	@git rev-parse -q --verify "refs/tags/v$(VERSION)" >/dev/null || (echo "ERROR: tag v$(VERSION) not found." >&2; exit 1)
	@command -v gh >/dev/null 2>&1 || (echo "ERROR: gh CLI is required. Install gh and run: gh auth login" >&2; exit 1)
	@echo "Preparing release notes from CHANGELOG.md..."
	@body="$$(awk '/^##  *v?$(VERSION)/{flag=1;next}/^##  /{flag=0}flag' CHANGELOG.md)"; [ -n "$$body" ] || body="See CHANGELOG.md for $(VERSION) details."
	@if gh release view v$(VERSION) >/dev/null 2>&1; then 		gh release edit v$(VERSION) --title "lib_bash $(VERSION)" --notes "$$body" --target HEAD; 	else 		gh release create v$(VERSION) --title "lib_bash $(VERSION)" --notes "$$body" --target HEAD; 	fi
