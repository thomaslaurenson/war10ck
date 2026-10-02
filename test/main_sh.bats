bats_require_minimum_version 1.7.0

load helpers/common

# Unit tests for the flag parser, fetch resolver and manifest loader in main.sh.
# main.sh ends with `main "$@"`, so it self-executes when sourced; the setup
# strips that one line into a copy that can be sourced to reach the functions
# in isolation.
# WAR10CK_BUILD=release is exported so the dev-build auto-enable of local/skip
# mode does not mask what the flags themselves do.
#
# Environment:
#   MAIN - path to a de-executed copy of main.sh
setup() {
  REPO_ROOT="$(_repo_root)"
  MAIN="$BATS_TEST_TMPDIR/main_noexec.sh"
  sed '/^main "\$@"$/d' "$REPO_ROOT/src/main.sh" > "$MAIN"
}

@test "_parse_flags: release-build defaults keep local, skip and debug off" {
  run bash -c "
    export WAR10CK_BUILD=release
    source '$MAIN'
    _parse_flags install docker
    printf '%s %s %s | %s\n' \"\$WAR10CK_LOCAL\" \"\$WAR10CK_SKIP_CHECKSUMS\" \"\$WAR10CK_DEBUG\" \"\${_ARGS[*]}\"
  "
  (( status == 0 ))
  [[ "$output" == "0 0 0 | install docker" ]]
}

@test "_parse_flags: -l and -s enable local mode and checksum skip and are stripped" {
  run bash -c "
    export WAR10CK_BUILD=release
    source '$MAIN'
    _parse_flags -l -s apply desktop
    printf '%s %s | %s\n' \"\$WAR10CK_LOCAL\" \"\$WAR10CK_SKIP_CHECKSUMS\" \"\${_ARGS[*]}\"
  "
  (( status == 0 ))
  [[ "$output" == "1 1 | apply desktop" ]]
}

@test "_parse_flags: --debug is recognised and consumed" {
  run bash -c "
    export WAR10CK_BUILD=release
    source '$MAIN'
    _parse_flags --debug version
    printf '%s | %s\n' \"\$WAR10CK_DEBUG\" \"\${_ARGS[*]}\"
  "
  (( status == 0 ))
  [[ "$output" == "1 | version" ]]
}

@test "_resolve_fetch: local mode prefers a dist/ directory under the cwd" {
  local work="$BATS_TEST_TMPDIR/work"
  mkdir -p "$work/dist/modules"
  run bash -c "
    export WAR10CK_BUILD=release
    source '$MAIN'
    WAR10CK_LOCAL=1
    cd '$work'
    _resolve_fetch
    printf '%s | %s\n' \"\$BASE_URL\" \"\$FETCH_CMD\"
  "
  (( status == 0 ))
  [[ "$output" == "$work/dist | _bcp" ]]
}

@test "_resolve_fetch: local mode falls back to a bare modules/ directory" {
  local work="$BATS_TEST_TMPDIR/work"
  mkdir -p "$work/modules"
  run bash -c "
    export WAR10CK_BUILD=release
    source '$MAIN'
    WAR10CK_LOCAL=1
    cd '$work'
    _resolve_fetch
    printf '%s | %s\n' \"\$BASE_URL\" \"\$FETCH_CMD\"
  "
  (( status == 0 ))
  [[ "$output" == "$work | _bcp" ]]
}

@test "_resolve_fetch: local mode errors when no modules directory is found" {
  local work="$BATS_TEST_TMPDIR/work"
  mkdir -p "$work"
  run bash -c "
    export WAR10CK_BUILD=release
    source '$MAIN'
    WAR10CK_LOCAL=1
    cd '$work'
    _resolve_fetch 2>&1
  "
  (( status == 1 ))
  [[ "$output" =~ "cannot find a modules/ directory" ]]
}

# Turn a fixture dist into a published one: take the pin over checksums.txt,
# then append the binary's own hash line, which is what bundle.sh does.
#
# Arguments:
#   $1 - fixture dist directory, built by _build_local_dist
# Outputs:
#   the pin (sha256 of checksums.txt without the binary's line) on stdout
_publish_manifest() {
  local root=$1 pin
  pin=$(sha256sum "$root/checksums.txt" | cut -d' ' -f1)
  printf '%s  war10ck\n' "$(printf 'binary\n' | sha256sum | cut -d' ' -f1)" \
    >> "$root/checksums.txt"
  printf '%s\n' "$pin"
}

@test "_load_manifest: accepts the pinned manifest and keeps only the verified lines" {
  local root="$BATS_TEST_TMPDIR/dist" pin
  _build_local_dist "$root"
  pin=$(_publish_manifest "$root")
  run bash -c "
    export WAR10CK_BUILD=release
    source '$REPO_ROOT/src/lib/private.sh'
    source '$MAIN'
    CHECKSUMS_SHA256='$pin' FETCH_CMD=_bcp BASE_URL='$root'
    _load_manifest install
    printf '%s\n' \"\$WAR10CK_MANIFEST\"
  "
  (( status == 0 ))
  [[ "$output" =~ "modules/demo/install.sh" ]]
  [[ ! "$output" =~ "war10ck" ]]
}

@test "_load_manifest: rejects a forged line hidden behind a trailing war10ck field" {
  # The pin covers the manifest minus the binary's own line. A filter loose
  # enough to drop any line ending in " war10ck" would also drop this one from
  # the pinned bytes while every lookup still read it.
  local root="$BATS_TEST_TMPDIR/dist" pin
  _build_local_dist "$root"
  pin=$(_publish_manifest "$root")
  { printf '%s  profiles/foo war10ck\n' "$(printf 'evil\n' | sha256sum | cut -d' ' -f1)"
    cat "$root/checksums.txt"
  } > "$root/forged"
  mv "$root/forged" "$root/checksums.txt"
  run bash -c "
    export WAR10CK_BUILD=release
    source '$REPO_ROOT/src/lib/private.sh'
    source '$MAIN'
    CHECKSUMS_SHA256='$pin' FETCH_CMD=_bcp BASE_URL='$root'
    _load_manifest install 2>&1
  "
  (( status == 1 ))
  [[ "$output" =~ "Checksum mismatch" ]]
}
