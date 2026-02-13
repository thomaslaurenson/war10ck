# INSTALL
install_locally:
	@cd dist && \
	sed -i "s/^IS_LOCAL=.*/IS_LOCAL=true/" install.sh && \
	./install.sh && \
	sed -i "s/^IS_LOCAL=.*/IS_LOCAL=false/" install.sh

# LINTING
lint:
	find -type f -name "*.sh" | xargs shellcheck
	find -type f -name "war10ck" | xargs shellcheck

# DOCS
docs:
	@echo "[*] Building docs..."
	@mkdir -p dist
	pandoc --standalone --metadata title="war10ck" --from=markdown --to=html5 --output=dist/index.html dist/README.md

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
