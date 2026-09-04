.DEFAULT_GOAL := help

UUID   := ghostty-quick-terminal@abn.is
SCHEMA := src/schemas/org.gnome.shell.extensions.ghostty-quick-terminal.gschema.xml
ZIP    := dist/$(UUID).shell-extension.zip
JS     := $(shell find src tests -name '*.js')

.PHONY: setup build install uninstall check fmt lint test clean docs/check shell/check js/check schema/check metadata/check release/check test/headless help

##@ Bootstrap

setup: ## Install git hooks and generate tool shims
	@./.agents/bootstrap.sh

##@ Build & Quality

build: $(ZIP) ## Pack the extension into dist/

$(ZIP): $(JS) src/metadata.json src/quick-terminal.conf $(SCHEMA)
	@mkdir -p dist
	gnome-extensions pack --force --out-dir=dist --extra-source=lib --extra-source=quick-terminal.conf --schema=schemas/$(notdir $(SCHEMA)) src

install: build ## Install the packed extension for the current user
	gnome-extensions install --force $(ZIP)
	@printf 'Log out and back in, then: gnome-extensions enable $(UUID)\n'

uninstall: ## Remove the extension for the current user
	gnome-extensions uninstall $(UUID)

check: lint test ## Run every quality gate (used by hooks and CI)

fmt: ## Format source files
	@printf 'fmt: no formatter configured yet\n'

lint: docs/check shell/check js/check schema/check metadata/check ## Lint docs, scripts, JS, schema and metadata

test: ## Run unit tests for the pure modules
	gjs -m tests/run.js

test/headless: build ## Drive the built extension in an isolated headless shell
	@./test/headless/run.sh $(ZIP) $(UUID)

clean: ## Remove build artifacts
	rm -rf build dist

##@ Utilities

docs/check: ## Validate the docs wiki (OKF v0.2 and privacy hygiene)
	@./.agents/scripts/docs-check.sh docs

js/check: ## Syntax-check every JS module
	@for f in $(JS); do node --input-type=module --check < "$$f" || exit 1; done; printf 'js/check: ok\n'

# extensions.gnome.org owns the version field; shipping one breaks updates.
metadata/check: ## Validate metadata.json for extensions.gnome.org
	@python3 -c 'import json,sys; m=json.load(open("src/metadata.json")); \
	  sys.exit("metadata/check: drop the version field" if "version" in m else 0); ' \
	  && printf 'metadata/check: ok\n'

release/check: ## Check that TAG matches version-name in metadata.json
	@test -n "$(TAG)" || { printf 'release/check: pass TAG=vX.Y.Z\n'; exit 1; }
	@python3 -c 'import json,sys; m=json.load(open("src/metadata.json")); \
	  sys.exit(0 if "v"+m["version-name"]=="$(TAG)" else "release/check: tag $(TAG) does not match version-name "+m["version-name"])' \
	  && printf 'release/check: ok\n'

schema/check: ## Validate the GSettings schema
	@glib-compile-schemas --strict --dry-run src/schemas && printf 'schema/check: ok\n'

# shellcheck is optional locally; CI should install it.
shell/check: ## Lint shell scripts with shellcheck when available
	@if command -v shellcheck >/dev/null 2>&1; then \
	  shellcheck .agents/bootstrap.sh .agents/hooks/* .agents/scripts/*.sh test/headless/*.sh; \
	else printf 'shell/check: shellcheck not installed, skipping\n'; fi

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
	  /^[a-zA-Z0-9_/-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } \
	  /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' $(MAKEFILE_LIST)
