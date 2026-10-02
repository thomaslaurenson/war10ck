bats_require_minimum_version 1.7.0

load helpers/common

# Configure the environment before each test.
#
# Environment:
#   REPO_ROOT - absolute path to the repository root, derived from BATS_TEST_DIRNAME
#   ENV_FILE  - path to the sourced environment fragment under test
#   BIN       - PATH directory holding the fnm stub
setup() {
  REPO_ROOT="$(_repo_root)"
  ENV_FILE="$REPO_ROOT/src/modules/fnm/files/env.bash"
  BIN="$BATS_TEST_TMPDIR/bin"
  _capturing_stub "$BIN" fnm
}

@test "env: sets up fnm without switching version on cd" {
  # --use-on-cd acts on a directory's .nvmrc, which fnm accepts as a path, so
  # a cloned repository could supply the node every later command runs.
  run env -i HOME="$BATS_TEST_TMPDIR/home" PATH="$BIN:/usr/bin:/bin" \
    bash --norc --noprofile -c "source '$ENV_FILE'"
  (( status == 0 ))
  [[ "$(cat "$BIN/fnm.calls")" == "env --shell bash" ]]
}
