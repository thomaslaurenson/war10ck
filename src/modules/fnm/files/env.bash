export FNM_DIR="$HOME/.local/share/fnm"

# The default alias is a symlink to the default Node installation, so its bin
# directory hands node, npm and npx to any shell that reaches this file,
# including one where the fnm environment below never gets set up.
export PATH="$FNM_DIR/aliases/default/bin:$PATH"

# fnm env prepends a per-shell path ahead of the default above. Switching
# version is left to an explicit fnm use rather than --use-on-cd, which acts on
# whatever .nvmrc or .node-version a directory holds: fnm reads anything that
# is not a version as an alias name, paths included, so a cloned repository
# could point node, npm and npx at binaries it ships.
if command -v fnm > /dev/null 2>&1; then
    eval "$(fnm env --shell bash)"
fi
