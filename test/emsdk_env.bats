bats_require_minimum_version 1.7.0

load helpers/common

# Configure the environment before each test.
#
# Environment:
#   REPO_ROOT - absolute path to the repository root, derived from BATS_TEST_DIRNAME
#   ENV_FILE  - path to the sourced environment fragment under test
#   HOME_DIR  - HOME for the shell that sources the fragment
setup() {
  REPO_ROOT="$(_repo_root)"
  ENV_FILE="$REPO_ROOT/src/modules/emsdk/files/env.bash"
  HOME_DIR="$BATS_TEST_TMPDIR/home"
}

@test "env: puts emsdk and emcc first on PATH without printing anything" {
  # run captures stderr too, so exactly two lines means sourcing printed
  # nothing, which emsdk_env.sh would on every shell start.
  run env -i HOME="$HOME_DIR" PATH="/usr/bin:/bin" \
    bash --norc --noprofile -c "source '$ENV_FILE'; printf '%s\n' \"\$EMSDK\" \"\$PATH\""
  (( status == 0 ))
  (( ${#lines[@]} == 2 ))
  [[ "${lines[0]}" == "$HOME_DIR/.local/share/emsdk" ]]
  [[ "${lines[1]}" == "${lines[0]}:${lines[0]}/upstream/emscripten:/usr/bin:/bin" ]]
}

@test "env: sourcing again does not add the entries twice" {
  run env -i HOME="$HOME_DIR" PATH="/usr/bin:/bin" \
    bash --norc --noprofile -c "source '$ENV_FILE'; source '$ENV_FILE'; printf '%s\n' \"\$PATH\""
  (( status == 0 ))
  [[ "$output" == "$HOME_DIR/.local/share/emsdk:$HOME_DIR/.local/share/emsdk/upstream/emscripten:/usr/bin:/bin" ]]
}
