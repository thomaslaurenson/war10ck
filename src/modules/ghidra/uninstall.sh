#!/usr/bin/env bash
set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

w_sudo_remove_symlink "/usr/local/bin/ghidra"

# The install unpacks a versioned directory (ghidra_11.x_PUBLIC), so the exact
# name is not known ahead of time. Remove every version that is present.
while IFS= read -r ghidra_dir; do
  [[ -n "${ghidra_dir}" ]] && w_sudo_remove_dir "${ghidra_dir}"
done < <(find /opt -maxdepth 1 -type d -name "ghidra_*_PUBLIC*" | sort)

w_remove_file "$HOME/.local/share/applications/ghidra.desktop"

# NOTE: openjdk-21-jdk and unzip are left installed. They are general-purpose
# packages that other software is likely to depend on.

w_log_info "ghidra module uninstalled."
w_log_info "Note: openjdk-21-jdk and unzip were intentionally preserved."
