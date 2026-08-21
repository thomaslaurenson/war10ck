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
  HOME="$home" bash -c "VERSION=v9.9.9; source '$PUBLIC'; source '$LIB'; $*"
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
  [[ "$output" =~ installed_by=v9.9.9 ]]
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
  [[ "$output" =~ configured_by=v9.9.9 ]]
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
  [[ "$output" =~ -[[:space:]]+v9.9.9 ]]
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
    export HOME='$h' BASE_URL='$base' FETCH_CMD='_bcp' VERSION=v9.9.9
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
    export HOME='$h' BASE_URL='$base' FETCH_CMD='_bcp' VERSION=v9.9.9
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
