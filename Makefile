bundle:
	@bash bundle.sh

# CHECKSUMS: regenerate dist/checksums.txt and embed its hash (runs bundle automatically)
checksums: bundle
	@echo "[*] Checksums embedded in dist/war10ck (see CHECKSUMS_SHA256)."
	@grep "^CHECKSUMS_SHA256=" dist/war10ck

# INSTALL
install_locally: bundle
	@cd dist && \
	sed -i "s/^IS_LOCAL=.*/IS_LOCAL=true/" war10ck && \
	sed -i "s/^IS_LOCAL=.*/IS_LOCAL=true/" install.sh && \
	./install.sh && \
	sed -i "s/^IS_LOCAL=.*/IS_LOCAL=false/" install.sh && \
	sed -i "s/^IS_LOCAL=.*/IS_LOCAL=false/" war10ck

# LINTING
lint:
	shellcheck bundle.sh install.sh
	shellcheck src/main.sh src/lib/*.sh src/install/*.sh

# RELEASE
release:
	@LATEST_TAG=$$(git tag --sort=-v:refname | head -n 1); \
	echo "[*] Existing tag: $$LATEST_TAG"; \
	read -p "[*] Enter new tag: v" VERSION; \
	echo "[*] Proposed version: $$VERSION"; \
	read -p "[*] Tag and Release? (y/N) " yn; \
	case $$yn in \
		y ) git tag v$$VERSION && git push --tags && echo "[*] Released v$$VERSION";; \
		n ) echo "[*] Exiting...";; \
		* ) echo "[*] Invalid response... Exiting"; exit 1;; \
	esac
