bats_require_minimum_version 1.7.0

# Configure the environment before each test.
#
# Environment:
#   REPO_ROOT - absolute path to the repository root, derived from BATS_TEST_DIRNAME
#   LIB       - path to the sourced library under test
setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  LIB="$REPO_ROOT/src/lib/private.sh"
}

@test "_is_valid_subcommand: accepts a known subcommand" {
  run bash -c "
    source '$REPO_ROOT/src/lib/constants.sh'
    source '$LIB'
    _is_valid_subcommand install
  "
  (( status == 0 ))
}

@test "_is_valid_subcommand: rejects the removed nuke subcommand" {
  run bash -c "
    source '$REPO_ROOT/src/lib/constants.sh'
    source '$LIB'
    _is_valid_subcommand nuke
  "
  (( status != 0 ))
}

@test "_is_valid_subcommand: rejects an unknown subcommand" {
  run bash -c "
    source '$REPO_ROOT/src/lib/constants.sh'
    source '$LIB'
    _is_valid_subcommand bogus
  "
  (( status != 0 ))
}

@test "_is_valid_subcommand: rejects an empty subcommand" {
  run bash -c "
    source '$REPO_ROOT/src/lib/constants.sh'
    source '$LIB'
    _is_valid_subcommand ''
  "
  (( status != 0 ))
}

@test "_is_valid_target: accepts ordinary module and profile names" {
  local t
  for t in docker my-mod uv2 a.b_c-d; do
    run bash -c "source '$LIB'; _is_valid_target '$t'"
    (( status == 0 )) || { printf 'rejected valid target: %q\n' "$t"; return 1; }
  done
}

@test "_is_valid_target: rejects metacharacters, traversal and empty input" {
  # These are the inputs that would otherwise be interpolated into manifest
  # lookups and URLs; each must be turned away before that happens.
  local t
  for t in '.*' '.' '..' '../../etc' 'a;b' 'a b' '-lead' '' 'a/b'; do
    run bash -c "source '$LIB'; _is_valid_target '$t'"
    (( status != 0 )) || { printf 'accepted invalid target: %q\n' "$t"; return 1; }
  done
}

@test "_bcp: copies source to destination with reversed arguments" {
  printf 'payload\n' > "$BATS_TEST_TMPDIR/src.txt"
  run bash -c "
    source '$LIB'
    _bcp '$BATS_TEST_TMPDIR/dest.txt' '$BATS_TEST_TMPDIR/src.txt'
  "
  (( status == 0 ))
  [[ "$(cat "$BATS_TEST_TMPDIR/dest.txt")" == "payload" ]]
}

@test "_verify_checksum: exits 0 on a matching hash" {
  printf 'payload\n' > "$BATS_TEST_TMPDIR/f.txt"
  local expected
  expected=$(sha256sum "$BATS_TEST_TMPDIR/f.txt" | cut -d' ' -f1)
  run bash -c "
    source '$LIB'
    _verify_checksum '$BATS_TEST_TMPDIR/f.txt' '$expected'
  "
  (( status == 0 ))
}

@test "_verify_checksum: exits 1 and reports mismatch on a bad hash" {
  printf 'payload\n' > "$BATS_TEST_TMPDIR/f.txt"
  run bash -c "
    source '$LIB'
    _verify_checksum '$BATS_TEST_TMPDIR/f.txt' 'deadbeef'
  "
  (( status == 1 ))
  [[ "$output" =~ "Checksum mismatch" ]]
}

@test "_verify_checksum: deletes the file on mismatch" {
  printf 'payload\n' > "$BATS_TEST_TMPDIR/f.txt"
  run bash -c "
    source '$LIB'
    _verify_checksum '$BATS_TEST_TMPDIR/f.txt' 'deadbeef'
  "
  (( status == 1 ))
  [[ ! -f "$BATS_TEST_TMPDIR/f.txt" ]]
}

@test "_verify_checksum: skips verification when WAR10CK_SKIP_CHECKSUMS is 1" {
  printf 'payload\n' > "$BATS_TEST_TMPDIR/f.txt"
  run bash -c "
    export WAR10CK_SKIP_CHECKSUMS=1
    source '$LIB'
    _verify_checksum '$BATS_TEST_TMPDIR/f.txt' 'deadbeef'
  "
  (( status == 0 ))
  [[ -f "$BATS_TEST_TMPDIR/f.txt" ]]
}

@test "_verify_from_manifest: exits 0 when the manifest entry matches" {
  printf 'payload\n' > "$BATS_TEST_TMPDIR/f.txt"
  local hash
  hash=$(sha256sum "$BATS_TEST_TMPDIR/f.txt" | cut -d' ' -f1)
  run bash -c "
    export WAR10CK_MANIFEST='${hash}  modules/demo/install.sh'
    source '$LIB'
    _verify_from_manifest '$BATS_TEST_TMPDIR/f.txt' 'modules/demo/install.sh'
  "
  (( status == 0 ))
}

@test "_verify_from_manifest: exits 1 when the key is absent from the manifest" {
  printf 'payload\n' > "$BATS_TEST_TMPDIR/f.txt"
  run bash -c "
    export WAR10CK_MANIFEST='abc  modules/other/install.sh'
    source '$LIB'
    _verify_from_manifest '$BATS_TEST_TMPDIR/f.txt' 'modules/demo/install.sh'
  "
  (( status == 1 ))
  [[ "$output" =~ "No manifest entry found" ]]
}

@test "_verify_from_manifest: exits 1 when the manifest is not loaded" {
  printf 'payload\n' > "$BATS_TEST_TMPDIR/f.txt"
  run bash -c "
    export WAR10CK_MANIFEST=''
    source '$LIB'
    _verify_from_manifest '$BATS_TEST_TMPDIR/f.txt' 'modules/demo/install.sh'
  "
  (( status == 1 ))
  [[ "$output" =~ "Manifest not loaded" ]]
}
