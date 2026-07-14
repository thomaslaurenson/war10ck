GHIDRA_DIR=$(find /opt -maxdepth 1 -type d -name "ghidra_*_PUBLIC*" 2>/dev/null | sort | tail -n 1)
[[ -n "$GHIDRA_DIR" ]] && export GHIDRA_INSTALL_DIR="$GHIDRA_DIR"
