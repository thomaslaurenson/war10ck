SHELL := /bin/bash

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
	@bash bundle.sh
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
	@printf 'bash -n src/profiles/**/*.sh ... '
	@for f in src/profiles/**/*.sh; do bash -n "$$f" || { printf 'fail\n'; exit 1; }; done && printf 'ok\n'
	shellcheck src/main.sh src/lib/*.sh src/modules/**/*.sh src/profiles/**/*.sh
