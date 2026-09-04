.DEFAULT_GOAL := help

.PHONY: setup build check fmt lint test clean docs/check shell/check help

##@ Bootstrap

setup: ## Install git hooks and generate tool shims
	@./.agents/bootstrap.sh

##@ Build & Quality

build: ## Build the extension bundle
	@printf 'build: no extension sources yet\n'

check: lint test ## Run every quality gate (used by hooks and CI)

fmt: ## Format source files
	@printf 'fmt: no formatter configured yet\n'

lint: docs/check shell/check ## Lint docs and scripts

test: ## Run the test suite
	@printf 'test: no tests yet\n'

clean: ## Remove build artifacts
	rm -rf build dist

##@ Utilities

docs/check: ## Validate the docs wiki (OKF v0.2 and privacy hygiene)
	@./.agents/scripts/docs-check.sh docs

# shellcheck is optional locally; CI should install it.
shell/check: ## Lint shell scripts with shellcheck when available
	@if command -v shellcheck >/dev/null 2>&1; then \
	  shellcheck .agents/bootstrap.sh .agents/hooks/* .agents/scripts/*.sh; \
	else printf 'shell/check: shellcheck not installed, skipping\n'; fi

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
	  /^[a-zA-Z0-9_/-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
