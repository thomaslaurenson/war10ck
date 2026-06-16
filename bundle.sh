#!/bin/bash
set -euo pipefail

SRC="src"
DIST="dist"
BUILD_MODE="${BUILD_MODE:-release}"

_cleanup() {
  if [[ -d "$DIST" ]]; then
    printf '[!] Bundle failed — cleaning up %s/\n' "$DIST" >&2
    rm -rf "$DIST"
  fi
}
trap _cleanup ERR

echo "[*] Bundling war10ck..."
mkdir -p "$DIST"

_strip_shellcheck() { grep -v '^# shellcheck' "$1"; }

# Bundle: concatenate lib modules + main entrypoint into a single executable
{
    echo "#!/bin/bash"
    echo ""
    _strip_shellcheck "$SRC/lib/version.sh"
    echo ""
    _strip_shellcheck "$SRC/lib/constants.sh"
    echo ""
    _strip_shellcheck "$SRC/lib/private.sh"
    echo ""
    _strip_shellcheck "$SRC/lib/public.sh"
    echo ""
    _strip_shellcheck "$SRC/lib/update.sh"
    echo ""
    _strip_shellcheck "$SRC/lib/modules.sh" 
    echo ""
    _strip_shellcheck "$SRC/lib/completion.sh"
    echo ""
    _strip_shellcheck "$SRC/main.sh"
} > "$DIST/war10ck"
chmod +x "$DIST/war10ck"
echo "[*] Bundled: $DIST/war10ck"

rm -rf "$DIST/modules"
cp -r "$SRC/modules" "$DIST/modules"
echo "[*] Copied: $DIST/modules/"

rm -rf "$DIST/profiles"
cp -r "$SRC/profiles" "$DIST/profiles"
echo "[*] Copied: $DIST/profiles/"

# Copy the self-installer
cp "install.sh" "$DIST/install.sh"
echo "[*] Copied: $DIST/install.sh"

sed '1{/^#/d}' README.md > "$DIST/README.md"
echo "[*] Copied: $DIST/README.md"

echo "[*] Generating checksums.txt..."
(
    cd "$DIST"
    # Find files inside modules/ and profiles/
    find modules profiles -type f | sort | xargs sha256sum > checksums.txt
    sha256sum install.sh >> checksums.txt
)
echo "[*] Generated: $DIST/checksums.txt (without war10ck)"

CHECKSUMS_SHA256=$(sha256sum "$DIST/checksums.txt" | cut -d' ' -f1)
sed -i "s/^CHECKSUMS_SHA256=.*/CHECKSUMS_SHA256=\"$CHECKSUMS_SHA256\"/" "$DIST/war10ck"
echo "[*] Embedded CHECKSUMS_SHA256=$CHECKSUMS_SHA256"

if [[ "${BUILD_MODE}" == "release" ]]; then
  sed -i 's/^WAR10CK_BUILD=.*/WAR10CK_BUILD="release"/' "$DIST/war10ck"
  echo "[*] Embedded WAR10CK_BUILD=release"
else
  echo "[*] Skipped WAR10CK_BUILD override (dev mode)"
fi

# Now add the war10ck binary hash to checksums.txt (after embedding modified it)
(
    cd "$DIST"
    sha256sum war10ck >> checksums.txt
)
echo "[*] Added war10ck hash to checksums.txt"

echo "[*] Bundle complete."
