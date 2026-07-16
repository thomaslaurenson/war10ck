SHELL := /bin/bash

VERSION_FILE := src/lib/version.sh

# BUILD
.PHONY: help
help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

.PHONY: bundle
bundle: ## Bundle src into a release binary in dist/
	@bash bundle.sh

.PHONY: dev
dev: ## Bundle a dev binary (local mode + checksum skip built in)
	@BUILD_MODE=dev bash bundle.sh
	@printf '[*] Dev build ready. Run: dist/war10ck <subcommand>\n'

# LINT
.PHONY: lint
lint: ## Run bash -n syntax check and shellcheck on all scripts
	@printf 'bash -n src/main.sh ... '
	@bash -n src/main.sh && printf 'ok\n' || { printf 'fail\n'; exit 1; }
	@printf 'bash -n src/lib/*.sh ... '
	@for f in src/lib/*.sh; do bash -n "$$f" || { printf 'fail\n'; exit 1; }; done && printf 'ok\n'
	@printf 'bash -n src/modules/**/*.sh ... '
	@for f in src/modules/**/*.sh; do bash -n "$$f" || { printf 'fail\n'; exit 1; }; done && printf 'ok\n'
	@printf 'bash -n src/profiles/* ... '
	@for f in src/profiles/*; do bash -n "$$f" || { printf 'fail\n'; exit 1; }; done && printf 'ok\n'
	shellcheck src/main.sh src/lib/*.sh src/modules/**/*.sh src/profiles/* bundle.sh install.sh

# TEST
.PHONY: test
test: ## Run the bats test suite
	@test/extern/bats/bin/bats test/

# GET
.PHONY: get_version
get_version: ## Print the current version from the version fragment
	@grep -E '^readonly VERSION=' $(VERSION_FILE) | sed -E 's/.*"v?([^"]+)".*/\1/'

.PHONY: get_changelog
get_changelog: ## Print the changelog entry for the current version
	@awk '/^## /{ if (n++) exit } n' CHANGELOG.md

# CI
.PHONY: ci
ci: lint test ## Run everything the lint and test workflows run

.PHONY: clean
clean: ## Remove build artefacts
	@rm -rf dist
