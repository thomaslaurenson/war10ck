bats_require_minimum_version 1.7.0

load helpers/common

# Unit tests for the flag parser and fetch resolver in main.sh. main.sh ends
# with `main "$@"`, so it self-executes when sourced; the setup strips that one
# line into a copy that can be sourced to reach the functions in isolation.
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
