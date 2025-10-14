# INSTALL
install_locally:
	@cd dist && \
	sed -i "s/^IS_LOCAL=.*/IS_LOCAL=true/" install.sh && \
	./install.sh && \
	sed -i "s/^IS_LOCAL=.*/IS_LOCAL=false/" install.sh

# LINTING
lint: \
	lint_shell

lint_shell:
	find -type f -name "*.sh" | xargs shellcheck
	find -type f -name "war10ck" | xargs shellcheck

# DOCS
docs:
	@echo "[*] Building docs..."
	@mkdir -p dist
	pandoc --standalone --metadata title="war10ck" --from=markdown --to=html5 --output=dist/index.html dist/README.md
