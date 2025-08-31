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
	@$(MAKE) --no-print-directory lint
	@$(MAKE) --no-print-directory test

release: ## Bump version, update CHANGELOG, tag, push, and create GitHub release (uses `gh`)
	@python3 make_scripts/release.py
