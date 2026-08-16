#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

GPIPE_DIR="$HOME/.war10ck/gpipe.d"

for tool in gpipe moon narc prongs; do
  w_deploy_remote_file "modules/gpipe/files/${tool}" "$GPIPE_DIR/${tool}"
done

w_log_info "gpipe registry installed to $GPIPE_DIR"
w_log_info "Run 'war10ck gpipe' to check versions, 'war10ck gpipe update' to update."
w_log_info "Add a tool by dropping a file with repo=owner/name into that directory."
