bats_require_minimum_version 1.7.0

# Security invariants. These guard the trust chain: war10ck downloads code and
# runs it with sudo on every machine it is installed on, so a regression here
# is a remote-code-execution regression.
#
# Environment:
#   REPO_ROOT - absolute path to the repository root
#   PRIVATE   - path to the private library (verification helpers)
setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  PRIVATE="$REPO_ROOT/src/lib/private.sh"
  PUBLIC="$REPO_ROOT/src/lib/public.sh"
}

@test "no plaintext http URLs anywhere in the source tree" {
  # A sudo-installed payload fetched over http is trivially MITM-able. zezula.net
  # is exempted: it has no working HTTPS (its cert covers an unrelated domain),
  # and mpqeditor/install.sh pins a SHA256 fetched over a different channel, so
  # tampering in transit is still caught.
  run bash -c "grep -rn 'http://' '$REPO_ROOT/src' '$REPO_ROOT/install.sh' '$REPO_ROOT/bundle.sh' | grep -vE 'schemas|w3.org|xmlns|zezula.net'"
  (( status != 0 ))
}

@test "manifest verification matches the filename field exactly, not as a regex" {
  # A manifest key containing '.' must not match any-character; a key must not
  # match a longer path as a substring.
  run bash -c "
    export WAR10CK_MANIFEST='aaaaaaaa  modules/aXc/install.sh'
    source '$PRIVATE'
    # Ask for 'a.c' (regex would match 'aXc'); must be treated literally and fail.
    _verify_from_manifest /dev/null 'modules/a.c/install.sh'
  "
  (( status == 1 ))
  [[ "$output" =~ "No manifest entry found" ]]
}

@test "manifest verification rejects a substring/prefix collision" {
  run bash -c "
    export WAR10CK_MANIFEST='aaaaaaaa  modules/foo/install.sh.bak'
    source '$PRIVATE'
    _verify_from_manifest /dev/null 'modules/foo/install.sh'
  "
  (( status == 1 ))
  [[ "$output" =~ "No manifest entry found" ]]
}

@test "manifest verification accepts an exact match" {
  printf 'payload\n' > "$BATS_TEST_TMPDIR/f"
  local hash
  hash=$(sha256sum "$BATS_TEST_TMPDIR/f" | cut -d' ' -f1)
  run bash -c "
    export WAR10CK_MANIFEST='${hash}  modules/foo/install.sh'
    source '$PRIVATE'
    _verify_from_manifest '$BATS_TEST_TMPDIR/f' 'modules/foo/install.sh'
  "
  (( status == 0 ))
}

@test "a wrong hash in the manifest is rejected and the file is deleted" {
  printf 'payload\n' > "$BATS_TEST_TMPDIR/f"
  run bash -c "
    export WAR10CK_MANIFEST='deadbeef  modules/foo/install.sh'
    source '$PRIVATE'
    _verify_from_manifest '$BATS_TEST_TMPDIR/f' 'modules/foo/install.sh'
  "
  (( status == 1 ))
  [[ ! -f "$BATS_TEST_TMPDIR/f" ]]
}

@test "every module that downloads a third-party payload verifies it" {
  # Any lifecycle script that calls w_download must also verify what it fetched,
  # via w_verify_sha256 or w_github_checksums_verify. Fetching then sudo-moving
  # an unchecked binary is the failure this guards against. config.sh and
  # uninstall.sh are audited too: a download can appear in any of them.
  local f offenders=()
  for f in "$REPO_ROOT"/src/modules/*/install.sh \
           "$REPO_ROOT"/src/modules/*/config.sh \
           "$REPO_ROOT"/src/modules/*/uninstall.sh; do
    [[ -e "$f" ]] || continue
    if grep -q 'w_download' "$f"; then
      grep -qE 'w_verify_sha256|w_github_checksums_verify' "$f" \
        || offenders+=("$(basename "$(dirname "$f")")/$(basename "$f")")
    fi
  done
  [[ ${#offenders[@]} -eq 0 ]] || printf 'downloads without verification: %s\n' "${offenders[*]}"
  (( ${#offenders[@]} == 0 ))
}

@test "no module pipes a download straight into a shell" {
  # curl | bash / wget | sh executes remote code with no checkpoint at all.
  # Match a pipe into a shell interpreter as a command (end of line or followed
  # by a flag/space), excluding comments and false hits like "| sha256sum".
  run bash -c "grep -rnE '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba)?sh([[:space:]]|\$)' '$REPO_ROOT/src' | grep -vE ':[[:space:]]*#'"
  (( status != 0 ))
}

@test "checksum skip requires an explicit environment opt-in" {
  # WAR10CK_SKIP_CHECKSUMS must default to off; verification is the default path.
  run bash -c "
    unset WAR10CK_SKIP_CHECKSUMS
    printf 'payload\n' > '$BATS_TEST_TMPDIR/f'
    source '$PRIVATE'
    _verify_checksum '$BATS_TEST_TMPDIR/f' 'deadbeef'
  "
  (( status == 1 ))
}

@test "profile meta is verified against the manifest before use" {
  # _list_profiles and _run_profile fetch profiles/<name>/meta and read module
  # names out of it. That file must be checksum-verified like any other fetched
  # artifact, or a tampered meta could redirect a profile to arbitrary modules.
  # Verification is centralized in _load_profile_meta; both call sites must
  # route through it rather than fetching the meta file themselves.
  grep -qF '_verify_from_manifest "${_tmpfile}" "${meta_key}"' "$REPO_ROOT/src/lib/modules.sh"
  local n
  n=$(grep -cF '_load_profile_meta "${profile}"' "$REPO_ROOT/src/lib/modules.sh")
  [[ "$n" == "2" ]]
}

@test "self-update verification cannot be disabled by the skip flag" {
  # update() must not route its binary check through _verify_checksum, which
  # honours WAR10CK_SKIP_CHECKSUMS; replacing the root binary unverified is the
  # worst outcome. It must compare the hash inline instead.
  # No _verify_checksum *call* (a line beginning with the function name). The
  # only permitted mention is the comment explaining why it is avoided here.
  run grep -nE '^[[:space:]]*_verify_checksum' "$REPO_ROOT/src/lib/update.sh"
  (( status != 0 ))
  # Verification must instead happen inline via an explicit hash comparison.
  grep -q 'actual_hash' "$REPO_ROOT/src/lib/update.sh"
}

@test "self-update refuses to install an older or equal version" {
  run grep -q 'sort -V' "$REPO_ROOT/src/lib/update.sh"
  (( status == 0 ))
}
