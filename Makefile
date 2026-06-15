bundle:
	@bash bundle.sh

# CHECKSUMS: regenerate dist/checksums.txt and embed its hash (runs bundle automatically)
checksums: bundle
	@echo "[*] Checksums embedded in dist/war10ck (see CHECKSUMS_SHA256)."
	@grep "^CHECKSUMS_SHA256=" dist/war10ck

# INSTALL
install_locally: bundle
	@echo "[*] Bundle ready. Run: dist/war10ck -l <subcommand>"

# LINTING
lint:
	shellcheck bundle.sh install.sh
	shellcheck src/main.sh src/lib/*.sh src/modules/**/*.sh
