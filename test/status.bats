bats_require_minimum_version 1.7.0

load helpers/common

# Configure the environment before each test.
#
# Environment:
#   REPO_ROOT - absolute path to the repository root
#   LIB       - the status library under test
#   PUBLIC    - public helpers, which status depends on for logging
setup() {
  REPO_ROOT="$(_repo_root)"
  LIB="$REPO_ROOT/src/lib/status.sh"
  PUBLIC="$REPO_ROOT/src/lib/public.sh"
}

# Source the status library with HOME pointed at a scratch directory and a
# version stamped in, so the registry resolves against a fixture tree.
#
# Arguments:
#   $1   - the HOME to use
#   $2.. - shell code to run once loaded
_with_home() {
  local home=$1; shift
  HOME="$home" bash -c "VERSION=9.9.9; source '$PUBLIC'; source '$LIB'; $*"
}

# As _with_home, but with a manifest embedded, standing in for what bundle.sh
# bakes into a release binary.
#
# Arguments:
#   $1   - the HOME to use
#   $2   - manifest contents
#   $3.. - shell code to run once loaded
_with_manifest() {
  local home=$1 manifest=$2; shift 2
  HOME="$home" WAR10CK_EMBEDDED_MANIFEST="$manifest" \
    bash -c "VERSION=9.9.9; source '$PUBLIC'; source '$LIB'; $*"
}

# A manifest naming one module's install and config scripts.
_fixture_manifest() {
  printf '%s  modules/demo/install.sh\n%s  modules/demo/config.sh\n' "$1" "$2"
}

# As _fixture_manifest, with files the module ships under files/.
#
# Arguments:
#   $1   - install.sh hash
#   $2   - config.sh hash
#   $3.. - name=hash pairs, one per file under files/
_fixture_manifest_files() {
  _fixture_manifest "$1" "$2"
  shift 2
  local pair
  for pair in "$@"; do
    printf '%s  modules/demo/files/%s\n' "${pair#*=}" "${pair%%=*}"
  done
}

# Record an action against one manifest, then report status against another,
# standing in for a module applied by one build and checked by the next.
#
# Arguments:
#   $1 - the HOME to use
#   $2 - action to record: install or config
#   $3 - manifest the action ran with
#   $4 - manifest the checking build ships
_applied_then_shipped() {
  _with_manifest "$1" "$3" "WAR10CK_MANIFEST='$3' _w_registry_record demo $2"
  run _with_manifest "$1" "$4" "status"
}

@test "status: reports an empty registry without failing" {
  run _with_home "$BATS_TEST_TMPDIR/empty" "status"
  (( status == 0 ))
  [[ "$output" =~ "No modules recorded yet" ]]
}

@test "record: an install writes an entry stamped with the war10ck version" {
  local h="$BATS_TEST_TMPDIR/h"
  run _with_home "$h" "_w_registry_record golang install"
  (( status == 0 ))
  run cat "$h/.war10ck/registry.d/golang"
  [[ "$output" =~ installed=20 ]]
  [[ "$output" =~ installed_by=9.9.9 ]]
  [[ "$output" =~ configured= ]]
}

@test "record: a config does not clear the install fields" {
  # Each action rewrites the whole file, so the other action's fields have to
  # be read back and preserved rather than dropped.
  local h="$BATS_TEST_TMPDIR/h"
  _with_home "$h" "_w_registry_record golang install"
  local installed
  installed=$(grep '^installed=' "$h/.war10ck/registry.d/golang")
  _with_home "$h" "_w_registry_record golang config"
  run cat "$h/.war10ck/registry.d/golang"
  (( status == 0 ))
  [[ "$output" =~ $installed ]]
  [[ "$output" =~ configured_by=9.9.9 ]]
}

@test "record: an uninstall drops the entry" {
  local h="$BATS_TEST_TMPDIR/h"
  _with_home "$h" "_w_registry_record golang install"
  [[ -f "$h/.war10ck/registry.d/golang" ]]
  run _with_home "$h" "_w_registry_record golang uninstall"
  (( status == 0 ))
  [[ ! -f "$h/.war10ck/registry.d/golang" ]]
}

@test "record: uninstalling something never recorded is not an error" {
  local h="$BATS_TEST_TMPDIR/h"
  run _with_home "$h" "_w_registry_record neverseen uninstall"
  (( status == 0 ))
}

@test "status: shows a dash for an action that has not run" {
  local h="$BATS_TEST_TMPDIR/h"
  _with_home "$h" "_w_registry_record trivy install"
  run _with_home "$h" "status"
  (( status == 0 ))
  [[ "$output" =~ trivy ]]
  # installed is stamped, configured is not
  [[ "$output" =~ -[[:space:]]+9.9.9 ]]
}

@test "status: lists every recorded module" {
  local h="$BATS_TEST_TMPDIR/h"
  _with_home "$h" "_w_registry_record golang install"
  _with_home "$h" "_w_registry_record trivy install"
  _with_home "$h" "_w_registry_record uv config"
  run _with_home "$h" "status"
  (( status == 0 ))
  [[ "$output" =~ golang ]]
  [[ "$output" =~ trivy ]]
  [[ "$output" =~ uv ]]
}

@test "runner: a lifecycle script that fails is not recorded" {
  # The whole value of the registry is that it records what ran, not what was
  # attempted. _run_script executes under errexit, so a failing script must
  # take the run down before the record is written.
  local base="$BATS_TEST_TMPDIR/dist"
  _build_local_dist "$base"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$base/modules/demo/install.sh"
  ( cd "$base" && find modules profiles -type f -print0 | sort -z \
      | xargs -0 sha256sum > checksums.txt )

  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h"
  run bash -c "
    set -euo pipefail
    export HOME='$h' BASE_URL='$base' FETCH_CMD='_bcp' VERSION=9.9.9
    export WAR10CK_MANIFEST=\"\$(cat '$base/checksums.txt')\"
    source '$REPO_ROOT/src/lib/private.sh'
    source '$PUBLIC'
    source '$REPO_ROOT/src/lib/status.sh'
    source '$REPO_ROOT/src/lib/modules.sh'
    _run_script modules/demo install
  "
  (( status != 0 ))
  [[ ! -f "$h/.war10ck/registry.d/demo" ]]
}

@test "runner: a successful lifecycle script is recorded" {
  local base="$BATS_TEST_TMPDIR/dist"
  _build_local_dist "$base"

  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h"
  run bash -c "
    set -euo pipefail
    export HOME='$h' BASE_URL='$base' FETCH_CMD='_bcp' VERSION=9.9.9
    export WAR10CK_MANIFEST=\"\$(cat '$base/checksums.txt')\"
    source '$REPO_ROOT/src/lib/private.sh'
    source '$PUBLIC'
    source '$REPO_ROOT/src/lib/status.sh'
    source '$REPO_ROOT/src/lib/modules.sh'
    _run_script modules/demo install
  "
  (( status == 0 ))
  [[ "$output" =~ DEMO_INSTALLED ]]
  [[ -f "$h/.war10ck/registry.d/demo" ]]
}

@test "state: matching hashes read as current" {
  local h="$BATS_TEST_TMPDIR/h"
  local manifest; manifest=$(_fixture_manifest aaa bbb)
  _with_manifest "$h" "$manifest" "WAR10CK_MANIFEST='$manifest' _w_registry_record demo install"
  run _with_manifest "$h" "$manifest" "status"
  (( status == 0 ))
  [[ "$output" =~ current ]]
}

@test "state: a module whose script has changed reads as changed" {
  local h="$BATS_TEST_TMPDIR/h"
  local applied; applied=$(_fixture_manifest aaa bbb)
  local shipped; shipped=$(_fixture_manifest ZZZ bbb)
  _with_manifest "$h" "$applied" "WAR10CK_MANIFEST='$applied' _w_registry_record demo install"
  run _with_manifest "$h" "$shipped" "status"
  (( status == 0 ))
  [[ "$output" =~ changed ]]
  [[ "$output" =~ "Re-apply them" ]]
}

@test "state: an entry recorded before hashes existed reads as unknown" {
  # An old entry has timestamps but no _sha fields. Treating that as current
  # would be a clean bill of health nobody checked.
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h/.war10ck/registry.d"
  printf 'installed=2026-01-01T00:00:00Z\ninstalled_by=v0.8.0\n' \
    > "$h/.war10ck/registry.d/demo"
  run _with_manifest "$h" "$(_fixture_manifest aaa bbb)" "status"
  (( status == 0 ))
  [[ "$output" =~ unknown ]]
}

@test "status: the version column drops the v older builds recorded" {
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h/.war10ck/registry.d"
  printf 'installed=2026-01-01T00:00:00Z\ninstalled_by=v0.10.2\n' \
    > "$h/.war10ck/registry.d/demo"
  run _with_home "$h" "status"
  (( status == 0 ))
  [[ "$output" =~ 0.10.2 ]]
  [[ ! "$output" =~ v0.10.2 ]]
}

@test "state: no embedded manifest reads as unknown, never as current" {
  local h="$BATS_TEST_TMPDIR/h"
  _with_home "$h" "_w_registry_record demo install"
  run _with_home "$h" "status"
  (( status == 0 ))
  [[ "$output" =~ unknown ]]
  [[ ! "$output" =~ current ]]
}

@test "state: only the actions that ran are compared" {
  # demo was installed but never configured, so a config.sh hash that differs
  # must not drag the module to changed.
  local h="$BATS_TEST_TMPDIR/h"
  local applied; applied=$(_fixture_manifest aaa bbb)
  local shipped; shipped=$(_fixture_manifest aaa DIFFERENT)
  _with_manifest "$h" "$applied" "WAR10CK_MANIFEST='$applied' _w_registry_record demo install"
  run _with_manifest "$h" "$shipped" "status"
  (( status == 0 ))
  [[ "$output" =~ current ]]
}

@test "record: the hash of the script that ran is stored" {
  local h="$BATS_TEST_TMPDIR/h"
  local manifest; manifest=$(_fixture_manifest aaa bbb)
  _with_manifest "$h" "$manifest" "WAR10CK_MANIFEST='$manifest' _w_registry_record demo config"
  run cat "$h/.war10ck/registry.d/demo"
  (( status == 0 ))
  [[ "$output" =~ configured_sha=bbb ]]
}

@test "get: an absent key returns empty and succeeds" {
  # The root cause of the half-completed apply: this helper's last command used
  # to be a grep pipeline, so a missing key made the function return 1 and
  # errexit killed the caller before it could write anything.
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h/.war10ck/registry.d"
  printf 'installed=x\n' > "$h/.war10ck/registry.d/demo"
  run _with_home "$h" \
    "set -euo pipefail; v=\$(_w_registry_get '$h/.war10ck/registry.d/demo' installed_sha); printf 'ok:%s' \"\$v\""
  (( status == 0 ))
  [[ "$output" == "ok:" ]]
}

@test "record: rewrites an entry written before the hash fields existed" {
  # The upgrade path from 0.10.0. The old entry has four keys, not six, and
  # recording over it must succeed and keep the action it does not touch.
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h/.war10ck/registry.d"
  printf 'installed=2026-01-01T00:00:00Z\ninstalled_by=v0.10.0\n' \
    > "$h/.war10ck/registry.d/demo"
  printf 'configured=2026-01-02T00:00:00Z\nconfigured_by=v0.10.0\n' \
    >> "$h/.war10ck/registry.d/demo"
  run _with_home "$h" "set -euo pipefail; _w_registry_record demo install"
  (( status == 0 ))
  run cat "$h/.war10ck/registry.d/demo"
  [[ "$output" =~ installed_by=9.9.9 ]]
  [[ "$output" =~ configured=2026-01-02T00:00:00Z ]]
  [[ "$output" =~ configured_by=v0.10.0 ]]
}

@test "runner: apply completes both steps over a pre-hash entry" {
  # The symptom users saw: install ran, the recorder aborted, and config was
  # never reached, leaving the module half applied with no error printed.
  local base="$BATS_TEST_TMPDIR/dist"
  _build_local_dist "$base"
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h/.war10ck/registry.d"
  printf 'installed=2026-01-01T00:00:00Z\ninstalled_by=v0.10.0\n' \
    > "$h/.war10ck/registry.d/demo"

  run bash -c "
    set -euo pipefail
    export HOME='$h' BASE_URL='$base' FETCH_CMD='_bcp' VERSION=9.9.9
    export WAR10CK_MANIFEST=\"\$(cat '$base/checksums.txt')\"
    source '$REPO_ROOT/src/lib/private.sh'
    source '$PUBLIC'
    source '$REPO_ROOT/src/lib/status.sh'
    source '$REPO_ROOT/src/lib/modules.sh'
    _run_script modules/demo install
    _run_script modules/demo config
  "
  (( status == 0 ))
  [[ "$output" =~ DEMO_INSTALLED ]]
  [[ "$output" =~ DEMO_CONFIGURED ]]
}

@test "record: the hash of the module's files is stored for the action that ran" {
  local h="$BATS_TEST_TMPDIR/h"
  local manifest; manifest=$(_fixture_manifest_files aaa bbb functions=fff)
  _with_manifest "$h" "$manifest" "WAR10CK_MANIFEST='$manifest' _w_registry_record demo config"
  run cat "$h/.war10ck/registry.d/demo"
  [[ "$output" =~ configured_files_sha=[0-9a-f]{64} ]]
  [[ "$output" =~ installed_files_sha=$'\n' ]]
}

@test "record: a module that ships no files records none" {
  local h="$BATS_TEST_TMPDIR/h"
  local manifest; manifest=$(_fixture_manifest aaa bbb)
  _with_manifest "$h" "$manifest" "WAR10CK_MANIFEST='$manifest' _w_registry_record demo install"
  run cat "$h/.war10ck/registry.d/demo"
  [[ "$output" =~ installed_files_sha=none ]]
}

@test "record: with no manifest, no files hash is claimed" {
  # none would say the module ships no files, which nothing has shown.
  local h="$BATS_TEST_TMPDIR/h"
  _with_home "$h" "_w_registry_record demo install"
  run cat "$h/.war10ck/registry.d/demo"
  [[ "$output" =~ installed_files_sha=$'\n' ]]
}

@test "state: unchanged scripts and files read as current" {
  local h="$BATS_TEST_TMPDIR/h"
  local manifest; manifest=$(_fixture_manifest_files aaa bbb functions=fff gitconfig=ggg)
  _applied_then_shipped "$h" config "$manifest" "$manifest"
  (( status == 0 ))
  [[ "$output" =~ current ]]
}

@test "state: a changed file reads as changed though no script changed" {
  # The git module: config.sh only deploys files/functions.bash, so a new
  # function library leaves every script hash as it was.
  local h="$BATS_TEST_TMPDIR/h"
  local applied; applied=$(_fixture_manifest_files aaa bbb functions=fff)
  local shipped; shipped=$(_fixture_manifest_files aaa bbb functions=NEW)
  _applied_then_shipped "$h" config "$applied" "$shipped"
  (( status == 0 ))
  [[ "$output" =~ changed ]]
  [[ "$output" =~ "Re-apply them" ]]
}

@test "state: a file added or removed reads as changed" {
  local h="$BATS_TEST_TMPDIR/h"
  local one; one=$(_fixture_manifest_files aaa bbb functions=fff)
  local two; two=$(_fixture_manifest_files aaa bbb functions=fff extra=eee)
  _applied_then_shipped "$h" config "$one" "$two"
  [[ "$output" =~ changed ]]
  rm -rf "$h"
  _applied_then_shipped "$h" config "$two" "$one"
  [[ "$output" =~ changed ]]
}

@test "state: a module that gains its first file reads as changed" {
  local h="$BATS_TEST_TMPDIR/h"
  local applied; applied=$(_fixture_manifest aaa bbb)
  local shipped; shipped=$(_fixture_manifest_files aaa bbb functions=fff)
  _applied_then_shipped "$h" install "$applied" "$shipped"
  [[ "$output" =~ changed ]]
}

@test "state: another module's files do not count" {
  local h="$BATS_TEST_TMPDIR/h"
  local applied; applied=$(_fixture_manifest_files aaa bbb functions=fff)
  local shipped
  shipped=$(printf '%s\n%s\n' "$applied" 'zzz  modules/other/files/functions.bash')
  _applied_then_shipped "$h" config "$applied" "$shipped"
  [[ "$output" =~ current ]]
}

@test "state: an entry from before files were tracked is unknown when the module has files" {
  # Every entry written up to 0.22.0. Its script hash still matches, but
  # nothing says which files it deployed, so current would be a guess.
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h/.war10ck/registry.d"
  printf 'configured=2026-01-01T00:00:00Z\nconfigured_by=0.22.0\nconfigured_sha=bbb\n' \
    > "$h/.war10ck/registry.d/demo"
  run _with_manifest "$h" "$(_fixture_manifest_files aaa bbb functions=fff)" "status"
  (( status == 0 ))
  [[ "$output" =~ unknown ]]
  [[ "$output" =~ "Re-apply them to start tracking" ]]
}

@test "state: an entry from before files were tracked stays current when the module has none" {
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h/.war10ck/registry.d"
  printf 'configured=2026-01-01T00:00:00Z\nconfigured_by=0.22.0\nconfigured_sha=bbb\n' \
    > "$h/.war10ck/registry.d/demo"
  run _with_manifest "$h" "$(_fixture_manifest aaa bbb)" "status"
  [[ "$output" =~ current ]]
}

@test "state: a definite change is not hidden by an action that cannot be compared" {
  # install predates file tracking and reads as unknown on its own; config has
  # since changed, which is the more useful thing to report.
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h/.war10ck/registry.d"
  printf '%s\n' 'installed=2026-01-01T00:00:00Z' 'installed_sha=aaa' \
    'configured=2026-01-01T00:00:00Z' 'configured_sha=OLD' \
    > "$h/.war10ck/registry.d/demo"
  run _with_manifest "$h" "$(_fixture_manifest_files aaa bbb functions=fff)" "status"
  [[ "$output" =~ changed ]]
}

@test "status: no hint to re-apply unknown modules in a dev build" {
  local h="$BATS_TEST_TMPDIR/h"
  _with_home "$h" "_w_registry_record demo install"
  run _with_home "$h" "status"
  [[ "$output" =~ unknown ]]
  [[ ! "$output" =~ "start tracking" ]]
}
