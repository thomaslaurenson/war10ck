bats_require_minimum_version 1.7.0

# Configure the environment before each test.
#
# Tests run against the bundled dev binary, which is the artefact users
# actually execute. The binary is built once per file by setup_file.
#
# Environment:
#   REPO_ROOT - absolute path to the repository root, derived from BATS_TEST_DIRNAME
#   BIN       - path to the bundled war10ck binary under test
setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  cd "$REPO_ROOT" || exit 1

  # A release binary is needed to exercise the remote-fetch paths, which are
  # compiled out of a dev build. Build it first and keep a copy, then leave a
  # dev build in dist/ for the rest of the suite.
  bash bundle.sh >/dev/null
  export REL_BIN="$BATS_FILE_TMPDIR/war10ck-release"
  cp "$REPO_ROOT/dist/war10ck" "$REL_BIN"

  BUILD_MODE=dev bash bundle.sh >/dev/null
}

# Build a PATH containing the coreutils war10ck needs but deliberately no
# curl and no wget, so the missing-fetch-tool branch can be exercised.
#
# Arguments:
#   $1 - Directory to populate with symlinks
_make_nonet_path() {
  local dir=$1
  mkdir -p "$dir"
  local t p
  for t in bash sed grep cut awk cat mktemp sha256sum rm mv cp mkdir dirname \
           basename chmod find sort xargs id tr head; do
    p=$(command -v "$t") && ln -sf "$p" "$dir/$t"
  done
}

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  BIN="$REPO_ROOT/dist/war10ck"
  cd "$REPO_ROOT" || exit 1
}

@test "bundle: binary enables errexit, nounset and pipefail when executed" {
  # Guarded rather than unconditional: the binary is also sourced into
  # interactive shells, where these options must not leak.
  run grep -q 'set -euo pipefail' "$BIN"
  (( status == 0 ))
  run grep -q 'BASH_SOURCE' "$BIN"
  (( status == 0 ))
}

@test "bundle: binary uses the portable env shebang" {
  run head -1 "$BIN"
  (( status == 0 ))
  [[ "$output" == "#!/usr/bin/env bash" ]]
}

@test "version: exits 0 and reports a dev build" {
  run "$BIN" version
  (( status == 0 ))
  [[ "$output" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-dev$ ]]
}

@test "no args: exits 0 and prints usage" {
  run "$BIN"
  (( status == 0 ))
  [[ "$output" =~ "Usage: war10ck" ]]
}

@test "help: -h exits 0 and lists the flags" {
  run "$BIN" -h
  (( status == 0 ))
  [[ "$output" =~ "--debug" ]]
  [[ "$output" =~ "--local" ]]
}

@test "help: does not offer a nuke subcommand" {
  run "$BIN" -h
  (( status == 0 ))
  [[ ! "$output" =~ "nuke" ]]
}

@test "dispatch: rejects an unknown subcommand" {
  run "$BIN" bogus
  (( status == 1 ))
  [[ "$output" =~ "Unknown subcommand: bogus" ]]
}

@test "dispatch: an unknown subcommand does not fetch a manifest" {
  run "$BIN" bogus
  (( status == 1 ))
  [[ ! "$output" =~ "Checksum" ]]
}

@test "apply: with no target lists modules and profiles" {
  run "$BIN" apply
  (( status == 0 ))
  [[ "$output" =~ "Modules:" ]]
  [[ "$output" =~ "Profiles:" ]]
}

@test "apply: rejects an unknown target" {
  run "$BIN" apply notarealtarget
  (( status == 1 ))
  [[ "$output" =~ "Unknown module or profile" ]]
}

@test "install: with no target lists modules with install support" {
  run "$BIN" install
  (( status == 0 ))
  [[ "$output" =~ "install support" ]]
  [[ "$output" =~ "docker" ]]
}

@test "install: rejects an unknown module" {
  run "$BIN" install notarealmodule
  (( status == 1 ))
  [[ "$output" =~ "Unknown module" ]]
}

@test "config: with no target lists modules with config support" {
  run "$BIN" config
  (( status == 0 ))
  [[ "$output" =~ "config support" ]]
}

@test "uninstall: with no target lists modules with uninstall support" {
  run "$BIN" uninstall
  (( status == 0 ))
  [[ "$output" =~ "uninstall support" ]]
}

@test "uninstall: rejects an unknown module" {
  run "$BIN" uninstall notarealmodule
  (( status == 1 ))
  [[ "$output" =~ "Unknown module" ]]
}

@test "list: capability tags reflect the scripts a module actually ships" {
  run "$BIN" apply
  (( status == 0 ))
  [[ "$output" =~ flatpak[[:space:]]+\[install\] ]]
}

@test "list: profile members are shown for the desktop profile" {
  run "$BIN" apply
  (( status == 0 ))
  [[ "$output" =~ "desktop" ]]
  [[ "$output" =~ "polybar" ]]
}

@test "flags: --debug is accepted before a subcommand" {
  run "$BIN" --debug version
  (( status == 0 ))
  [[ "$output" =~ "-dev" ]]
}

@test "flags: flags are stripped from the subcommand arguments" {
  run "$BIN" version --debug
  (( status == 0 ))
  [[ "$output" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-dev$ ]]
}

@test "manifest: checksums.txt covers every bundled module file" {
  run bash -c "
    cd '$REPO_ROOT/dist'
    sha256sum --quiet --check checksums.txt
  "
  (( status == 0 ))
}

@test "version: works on a host with no curl or wget" {
  local nonet="$BATS_TEST_TMPDIR/nonet"
  _make_nonet_path "$nonet"
  run env -i PATH="$nonet" HOME="$BATS_TEST_TMPDIR" "$REL_BIN" version
  (( status == 0 ))
  [[ "$output" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "help: works on a host with no curl or wget" {
  local nonet="$BATS_TEST_TMPDIR/nonet"
  _make_nonet_path "$nonet"
  run env -i PATH="$nonet" HOME="$BATS_TEST_TMPDIR" "$REL_BIN" -h
  (( status == 0 ))
  [[ "$output" =~ "Usage: war10ck" ]]
}

@test "install: reports a missing fetch tool rather than failing silently" {
  local nonet="$BATS_TEST_TMPDIR/nonet"
  _make_nonet_path "$nonet"
  run env -i PATH="$nonet" HOME="$BATS_TEST_TMPDIR" "$REL_BIN" install docker
  (( status != 0 ))
  [[ "$output" =~ "No fetch command found" ]]
}

@test "release: version reports no dev suffix" {
  run "$REL_BIN" version
  (( status == 0 ))
  [[ ! "$output" =~ "-dev" ]]
}

@test "sourcing: does not leak set -u into the shell" {
  # rundmc sources the binary into every interactive shell to register
  # completion. Leaking nounset would make any unset variable reference an
  # error, breaking ordinary shell use.
  run bash -c "
    set +u
    . '$BIN'
    shopt -o nounset | awk '{print \$2}'
  "
  (( status == 0 ))
  [[ "$output" == "off" ]]
}

@test "sourcing: does not leak errexit or pipefail into the shell" {
  run bash -c "
    set +u
    . '$BIN'
    printf '%s %s\n' \"\$(shopt -o errexit | awk '{print \$2}')\" \"\$(shopt -o pipefail | awk '{print \$2}')\"
  "
  (( status == 0 ))
  [[ "$output" == "off off" ]]
}

@test "sourcing: registers bash completion" {
  run bash -c "set +u; . '$BIN'; complete -p war10ck"
  (( status == 0 ))
  [[ "$output" =~ "_war10ck_completions" ]]
}

@test "sourcing: is idempotent and prints no readonly errors" {
  # 'source ~/.bashrc' is a common thing to do; it must not spew errors.
  run bash -c "set +u; . '$BIN' 2>&1; . '$BIN' 2>&1; . '$BIN' 2>&1"
  (( status == 0 ))
  [[ ! "$output" =~ "readonly variable" ]]
  [[ -z "$output" ]]
}

@test "executing: hardening is applied inside the sourced-vs-executed guard" {
  # The line after the BASH_SOURCE guard must be the hardening, so that it
  # applies on execution only.
  run bash -c "grep -A1 'BASH_SOURCE' '$BIN' | grep -c 'set -euo pipefail'"
  (( status == 0 ))
  [[ "$output" == "1" ]]
}

@test "targets: regex metacharacters are rejected as unknown modules" {
  local t
  for t in '.*' '.' '../../etc' 'a;b'; do
    run "$BIN" install "$t"
    (( status == 1 )) || { printf 'target %s was not rejected\n' "$t"; return 1; }
    [[ "$output" =~ "Unknown module" ]] || { printf 'bad message for %s: %s\n' "$t" "$output"; return 1; }
  done
}

@test "targets: a regex metacharacter target never reaches the fetch stage" {
  run "$BIN" install '.*'
  (( status == 1 ))
  [[ ! "$output" =~ "Running install" ]]
  [[ ! "$output" =~ "cannot stat" ]]
}

@test "bundle: the generated manifest hashes every module and profile file" {
  # Guards against the find|xargs manifest silently going empty or missing
  # files (spaces, zero matches). Compare the manifest's module/profile entries
  # against what is actually on disk in dist/.
  local on_disk manifest_count
  on_disk=$(cd "$REPO_ROOT/dist" && find modules profiles -type f | wc -l)
  manifest_count=$(grep -cE ' (modules|profiles)/' "$REPO_ROOT/dist/checksums.txt")
  [[ "$on_disk" == "$manifest_count" ]]
  (( on_disk > 0 ))
}
