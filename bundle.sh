#!/bin/bash


set -euo pipefail

SRC="src"
DIST="dist"

echo "[*] Bundling war10ck..."
mkdir -p "$DIST"

# Strip shellcheck directives from a fragment file — they are for per-file
# linting only and are redundant (or misleading) in the bundled output.
strip() { grep -v '^# shellcheck' "$1"; }

# Bundle: concatenate lib modules + main entrypoint into a single executable
{
    echo "#!/bin/bash"
    echo ""
    strip "$SRC/lib/constants.sh"
    echo ""
    strip "$SRC/lib/helpers.sh"
    echo ""
    strip "$SRC/lib/commands.sh"
    echo ""
    strip "$SRC/lib/config.sh"
    echo ""
    strip "$SRC/lib/install.sh"
    echo ""
    strip "$SRC/lib/completion.sh"
    echo ""
    strip "$SRC/main.sh"
} > "$DIST/war10ck"
chmod +x "$DIST/war10ck"
echo "[*] Bundled: $DIST/war10ck"

# Copy install scripts and config files
rm -rf "$DIST/install"
cp -r "$SRC/install" "$DIST/install"
echo "[*] Copied: $DIST/install/"

rm -rf "$DIST/config"
cp -r "$SRC/config" "$DIST/config"
echo "[*] Copied: $DIST/config/"

# Copy the self-installer
cp "install.sh" "$DIST/install.sh"
echo "[*] Copied: $DIST/install.sh"

# Build README: strip the H1 title line (pandoc uses --metadata title instead)
sed '1{/^#/d}' README.md > "$DIST/README.md"
echo "[*] Copied: $DIST/README.md"

# Generate checksums.txt for all files that war10ck downloads at runtime.
# Paths are stored relative to $DIST so they match the manifest_key used in the scripts.
echo "[*] Generating checksums.txt..."
(
    cd "$DIST"
    # Collect install scripts, config files, and the self-installer
    find install config -type f | sort | xargs sha256sum > checksums.txt
    sha256sum install.sh >> checksums.txt
)
echo "[*] Generated: $DIST/checksums.txt (without war10ck)"

# Embed the SHA256 of checksums.txt into the bundled war10ck script so it can
# verify the manifest on fetch before trusting any of its entries.
CHECKSUMS_SHA256=$(sha256sum "$DIST/checksums.txt" | cut -d' ' -f1)
sed -i "s/^CHECKSUMS_SHA256=.*/CHECKSUMS_SHA256=\"$CHECKSUMS_SHA256\"/" "$DIST/war10ck"
echo "[*] Embedded CHECKSUMS_SHA256=$CHECKSUMS_SHA256"

# Now add the war10ck binary hash to checksums.txt (after embedding modified it)
(
    cd "$DIST"
    sha256sum war10ck >> checksums.txt
)
echo "[*] Added war10ck hash to checksums.txt"

echo "[*] Bundle complete."
