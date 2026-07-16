bats_require_minimum_version 1.7.0

load helpers/common

# The module/profile execution engine in modules.sh: the fetch -> verify ->
# execute pipeline that actually runs downloaded code, plus the profile member
# parser. These are driven against a local fixture dist with _bcp standing in
# for the network fetch, so the real security checkpoint (_verify_from_manifest)
# runs with verification left ON (WAR10CK_LOCAL and WAR10CK_SKIP_CHECKSUMS unset).
#
# Environment:
#   REPO_ROOT   - repository root
#   PRIVATE     - private library (verify + _bcp helpers)
#   MODULES_LIB - modules library (execution engine)
setup() {
  REPO_ROOT="$(_repo_root)"
  PRIVATE="$REPO_ROOT/src/lib/private.sh"
  MODULES_LIB="$REPO_ROOT/src/lib/modules.sh"
}

# Emit the shell prelude that sources the libraries and wires up a fixture dist
# rooted at $1, with checksum verification active. Callers append the command
# under test on a following line.
_engine_env() {
  cat <<EOF
source '$PRIVATE'
source '$MODULES_LIB'
export FETCH_CMD=_bcp BASE_URL='$1'
export WAR10CK_MANIFEST="\$(cat '$1/checksums.txt')"
EOF
}

@test "_run_script: runs a module script whose checksum matches the manifest" {
  local root="$BATS_TEST_TMPDIR/dist"
  _build_local_dist "$root"
  run bash -c "$(_engine_env "$root")
_run_script 'modules/demo' 'install'"
  (( status == 0 ))
  [[ "$output" =~ "Running install for modules/demo" ]]
  [[ "$output" =~ "DEMO_INSTALLED" ]]
}

@test "_run_script: refuses to execute a script that fails checksum verification" {
  local root="$BATS_TEST_TMPDIR/dist"
  _build_local_dist "$root"
  # Tamper with the payload after the manifest was computed: the fetched file no
  # longer matches its recorded hash, so it must never reach the interpreter.
  printf 'printf "PWNED\\n"\n' >> "$root/modules/demo/install.sh"
  run bash -c "$(_engine_env "$root")
_run_script 'modules/demo' 'install' 2>&1"
  (( status == 1 ))
  [[ "$output" =~ "Checksum mismatch" ]]
  [[ ! "$output" =~ "DEMO_INSTALLED" ]]
  [[ ! "$output" =~ "PWNED" ]]
}

@test "_run_script: silently skips an action the manifest does not list" {
  local root="$BATS_TEST_TMPDIR/dist"
  _build_local_dist "$root"
  run bash -c "$(_engine_env "$root")
_run_script 'modules/demo' 'nonexistent'"
  (( status == 0 ))
  [[ -z "$output" ]]
}

@test "_run_profile: a bare module name runs both install and config" {
  local root="$BATS_TEST_TMPDIR/dist"
  _build_local_dist "$root"
  run bash -c "$(_engine_env "$root")
_run_profile foo"
  (( status == 0 ))
  [[ "$output" =~ "DEMO_INSTALLED" ]]
  [[ "$output" =~ "DEMO_CONFIGURED" ]]
}

@test "_run_profile: a :config member runs only the config step" {
  local root="$BATS_TEST_TMPDIR/dist"
  _build_local_dist "$root"
  run bash -c "$(_engine_env "$root")
_run_profile bar"
  (( status == 0 ))
  [[ ! "$output" =~ "DEMO_INSTALLED" ]]
  [[ "$output" =~ "DEMO_CONFIGURED" ]]
}

@test "_run_profile: rejects an unknown per-module step" {
  local root="$BATS_TEST_TMPDIR/dist"
  _build_local_dist "$root"
  run bash -c "$(_engine_env "$root")
_run_profile baz 2>&1"
  (( status == 1 ))
  [[ "$output" =~ "unknown step" ]]
}
