bats_require_minimum_version 1.7.0

load helpers/common

# Configure the environment before each test.
#
# Environment:
#   REPO_ROOT - absolute path to the repository root, derived from BATS_TEST_DIRNAME
#   FUNCTIONS - path to the sourced functions file under test
#   BIN       - PATH directory holding the pass stub
setup() {
  REPO_ROOT="$(_repo_root)"
  FUNCTIONS="$REPO_ROOT/src/modules/pass-env/files/functions.bash"
  BIN="$BATS_TEST_TMPDIR/bin"
  _capturing_stub "$BIN" pass
}

# Drive the completer as bash would for a line with the cursor at its end. A
# stand-in __passenv prints the COMP_ variables it receives, which is the whole
# contract: the real one is pass-env's and is tested there.
#
# Arguments:
#   $1 - the command line, exactly as typed
_complete() {
  run bash -c '
    source "$1"
    __passenv() {
      printf "LINE=[%s] POINT=%s CWORD=%s\n" "$COMP_LINE" "$COMP_POINT" "$COMP_CWORD"
      printf "WORD=[%s]\n" "${COMP_WORDS[@]}"
    }
    COMP_LINE=$2
    COMP_POINT=${#2}
    read -ra COMP_WORDS <<< "$2"
    [[ "$2" == *" " ]] && COMP_WORDS+=("")
    COMP_CWORD=$(( ${#COMP_WORDS[@]} - 1 ))
    _w_per_complete
  ' _ "$FUNCTIONS" "$1"
}

@test "per: forwards its arguments to pass env run" {
  run env "PATH=$BIN:$PATH" bash -c "source '$FUNCTIONS'; per env/api.env -- printenv TOKEN"
  (( status == 0 ))
  [[ "$(cat "$BIN/pass.calls")" == "env run env/api.env -- printenv TOKEN" ]]
}

@test "per: registers its completer" {
  run bash -c "source '$FUNCTIONS'; complete -p per"
  (( status == 0 ))
  [[ "$output" == "complete -F _w_per_complete per" ]]
}

@test "complete: rewrites the line as passenv run before delegating" {
  _complete "per env/a"
  (( status == 0 ))
  [[ "$output" =~ "LINE=[passenv run env/a] POINT=17 CWORD=2" ]]
  [[ "$output" =~ "WORD=[passenv]"$'\n'"WORD=[run]"$'\n'"WORD=[env/a]" ]]
}

@test "complete: keeps the empty word after a trailing space" {
  _complete "per "
  (( status == 0 ))
  [[ "$output" =~ "LINE=[passenv run ] POINT=12 CWORD=2" ]]
  [[ "$output" =~ "WORD=[run]"$'\n'"WORD=[]" ]]
}

@test "complete: leaves the words after -- for the command completer" {
  _complete "per env/a -- ls -"
  (( status == 0 ))
  [[ "$output" =~ "LINE=[passenv run env/a -- ls -] POINT=25 CWORD=5" ]]
  [[ "$output" =~ "WORD=[--]"$'\n'"WORD=[ls]"$'\n'"WORD=[-]" ]]
}

@test "complete: keeps the cursor in step when the line has leading spaces" {
  _complete "  per x"
  (( status == 0 ))
  [[ "$output" =~ "LINE=[passenv run x] POINT=13 CWORD=2" ]]
}

@test "complete: offers nothing when pass-env's completer is not loaded" {
  run bash -c "source '$FUNCTIONS'; COMP_LINE='per '; COMP_POINT=4; COMP_WORDS=(per ''); COMP_CWORD=1; _w_per_complete; printf '%s' \"\${COMPREPLY[*]:-}\""
  (( status == 0 ))
  [[ -z "$output" ]]
}
