export FNM_DIR="$HOME/.local/share/fnm"

# The default alias is a symlink to the default Node installation, so its bin
# directory hands node, npm and npx to any shell that reaches this file,
# including one where the fnm environment below never gets set up.
export PATH="$FNM_DIR/aliases/default/bin:$PATH"

# fnm env prepends a per-shell path ahead of the default above, and --use-on-cd
# repoints it on entering a directory that names a version in .nvmrc,
# .node-version or a package.json engines field.
if command -v fnm > /dev/null 2>&1; then
    eval "$(fnm env --use-on-cd --shell bash)"
fi
