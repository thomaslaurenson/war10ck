# LINTING
lint: \
	lint_shell

lint_shell:
	find -type f -name "*.sh" | xargs shellcheck
	find -type f -name "pub" | xargs shellcheck
