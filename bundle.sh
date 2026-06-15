#!/bin/bash
set -euo pipefail

SRC="src"
DIST="dist"

echo "[*] Bundling war10ck..."
mkdir -p "$DIST"

strip() { grep -v '^# shellcheck' "$1"; }

# Bundle: concatenate lib modules + main entrypoint into a single executable
{
    echo "#!/bin/bash"
    echo ""
    strip "$SRC/lib/version.sh"
    echo ""
    strip "$SRC/lib/constants.sh"
    echo ""
    strip "$SRC/lib/helpers.sh"
    echo ""
    strip "$SRC/lib/update.sh"
    echo ""
    strip "$SRC/lib/modules.sh" 
    echo ""
    strip "$SRC/lib/nuke.sh"
    echo ""
    strip "$SRC/lib/completion.sh"
    echo ""
    strip "$SRC/main.sh"
} > "$DIST/war10ck"
chmod +x "$DIST/war10ck"
echo "[*] Bundled: $DIST/war10ck"

rm -rf "$DIST/modules"
cp -r "$SRC/modules" "$DIST/modules"
echo "[*] Copied: $DIST/modules/"

# Copy the self-installer
cp "install.sh" "$DIST/install.sh"
echo "[*] Copied: $DIST/install.sh"

sed '1{/^#/d}' README.md > "$DIST/README.md"
echo "[*] Copied: $DIST/README.md"

echo "[*] Generating checksums.txt..."
(
    cd "$DIST"
    # Find files inside modules/
    find modules -type f | sort | xargs sha256sum > checksums.txt
    sha256sum install.sh >> checksums.txt
)
echo "[*] Generated: $DIST/checksums.txt (without war10ck)"

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
