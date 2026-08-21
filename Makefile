SHELL := /bin/bash

VERSION_FILE := src/lib/version.sh

# Every file lint checks. Scripts are found by extension; the sourced fragments
# are listed explicitly because bash sources rather than executes them, so they
# carry no extension and no shebang to match on.
#
# find rather than a shell glob: ** only recurses when globstar is set, and it
# is not set inside a recipe, so src/modules/**/*.sh silently stops one level
# down and skips every deployed file under src/modules/*/files.
LINT_SCRIPTS := $(shell find src test -type f \( -name '*.sh' -o -name '*.bash' \) \
                  -not -path 'test/extern/*' | sort)
LINT_SOURCED := src/modules/bash/files/rundmc \
                src/modules/bash/files/aliases \
                src/modules/bash/files/environment \
                src/modules/bash/files/history \
                $(wildcard src/modules/bash/files/functions.d/*)
LINT_FILES := $(LINT_SCRIPTS) $(LINT_SOURCED) $(wildcard src/profiles/*) bundle.sh install.sh

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
	@printf 'bash -n     %s files ... ' '$(words $(LINT_FILES))'
	@for f in $(LINT_FILES); do \
		bash -n "$$f" || { printf 'fail: %s\n' "$$f"; exit 1; }; \
	done && printf 'ok\n'
	@printf 'shellcheck  %s files ...\n' '$(words $(LINT_FILES))'
	shellcheck -s bash $(LINT_FILES)

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
