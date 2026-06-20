#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

WAR10CK_DIR="$HOME/.war10ck"

# Deploy shell config files
w_deploy_remote_file "modules/bash/files/rundmc"      "$WAR10CK_DIR/.rundmc"
w_deploy_remote_file "modules/bash/files/aliases"     "$WAR10CK_DIR/.aliases"
w_deploy_remote_file "modules/bash/files/environment" "$WAR10CK_DIR/.environment"
w_deploy_remote_file "modules/bash/files/history"     "$WAR10CK_DIR/.history"

# Deploy shell functions
for f in general github sshfs; do
  w_deploy_remote_file "modules/bash/files/functions.d/${f}" "$WAR10CK_DIR/functions.d/${f}"
done

# Create bashrc.d directory (unmanaged by war10ck - preserved on uninstall)
mkdir -p "$WAR10CK_DIR/bashrc.d"
chmod 700 "$WAR10CK_DIR/bashrc.d"

# Hook .rundmc into .bashrc if not already present
if ! grep -q "# war10ck BEGIN" "$HOME/.bashrc"; then
  printf '\n# war10ck BEGIN\nif [ -f %s/.rundmc ]; then\n    . %s/.rundmc\nfi\n# war10ck END\n' \
    "$WAR10CK_DIR" "$WAR10CK_DIR" >> "$HOME/.bashrc"
fi

w_log_info "bash module installed."
