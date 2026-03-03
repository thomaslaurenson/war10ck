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

echo "[*] Bundle complete."
