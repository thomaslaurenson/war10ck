SHELL := /bin/bash

VERSION_FILE := src/lib/version.sh
BATS_DIR := test/extern/bats

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
LINT_MOCKS := $(wildcard test/helpers/mock_*)
LINT_FILES := $(LINT_SCRIPTS) $(LINT_SOURCED) $(LINT_MOCKS) $(wildcard src/profiles/*) \
              bundle.sh install.sh

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

.PHONY: check_version
check_version: ## Check every file stating the version agrees with the embedded one
	@embedded="$$($(MAKE) --no-print-directory get_version)"; \
	heading="$$(sed -nE 's/^## ([0-9]+\.[0-9]+\.[0-9]+) .*/\1/p' CHANGELOG.md | head -1)"; \
	printf 'version     %s ... ' "$${embedded}"; \
	if [[ "$${embedded}" != "$${heading}" ]]; then \
		printf 'fail\n'; \
		printf '[!] CHANGELOG.md leads with %s; %s says %s\n' \
			"$${heading:-no version heading}" '$(VERSION_FILE)' "$${embedded}" >&2; \
		exit 1; \
	fi; \
	printf 'ok\n'

.PHONY: check_version_tag
check_version_tag: ## Check TAG=vX.Y.Z matches the embedded version
	@[[ -n "$(TAG)" ]] || { printf '[!] TAG is required: make check_version_tag TAG=vX.Y.Z\n' >&2; \
		exit 1; }
	@embedded="$$($(MAKE) --no-print-directory get_version)"; \
	tag="$(TAG)"; \
	printf 'tag         %s ... ' "$(TAG)"; \
	if [[ "$${tag#v}" != "$${embedded}" ]]; then \
		printf 'fail\n'; \
		printf '[!] Tag %s does not match %s (%s). Bump VERSION before tagging\n' \
			"$(TAG)" '$(VERSION_FILE)' "$${embedded}" >&2; \
		exit 1; \
	fi; \
	printf 'ok\n'

# TEST
.PHONY: test
test: ## Run the bats test suite
	@$(BATS_DIR)/bin/bats test/

# Dependabot is not used for this: the gitsubmodule ecosystem follows branch
# commits rather than releases, so it would land untagged development commits.
.PHONY: bump_bats
bump_bats: ## Move the bats submodule to the newest upstream release tag
	@url="$$(git config -f .gitmodules submodule.$(BATS_DIR).url)"; \
	tag="$$(git ls-remote --tags --refs "$${url}" 'v*' \
		| sed 's|.*refs/tags/||' \
		| grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$$' \
		| sort -V | tail -1)"; \
	[[ -n "$${tag}" ]] \
		|| { printf '[!] Could not determine the latest bats release\n' >&2; exit 1; }; \
	git -C $(BATS_DIR) fetch --depth 1 origin "refs/tags/$${tag}:refs/tags/$${tag}"; \
	git -C $(BATS_DIR) checkout --detach "$${tag}"; \
	printf '[~] bats moved to %s. Stage it with: git add %s\n' "$${tag}" '$(BATS_DIR)'

# GET
.PHONY: get_version
get_version: ## Print the current version from the version fragment
	@grep -E '^readonly VERSION=' $(VERSION_FILE) | sed -E 's/.*"v?([^"]+)".*/\1/'

.PHONY: get_changelog
get_changelog: ## Print the changelog entry for the current version
	@awk '/^## /{ if (n++) exit } n' CHANGELOG.md

# CI
.PHONY: ci
ci: lint check_version test ## Run everything the lint and test workflows run

.PHONY: clean
clean: ## Remove build artefacts
	@rm -rf dist
