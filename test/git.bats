bats_require_minimum_version 1.7.0

load helpers/common

# Exercise w_git_repository_properties against repositories in known states.
#
# The states are built rather than asserted against whatever the host happens to
# hold, because the two bugs this function used to carry (ahead and behind
# reporting each other's value, and a relative target reporting only the first
# repository) both produce plausible looking output. Only a fixture with a known
# answer catches them.
#
# Environment:
#   REPO_ROOT - absolute path to the repository root, derived from BATS_TEST_DIRNAME
#   FUNCTIONS - path to the sourced functions file under test
#   ORG       - the fixture directory of repositories
setup() {
  REPO_ROOT="$(_repo_root)"
  FUNCTIONS="$REPO_ROOT/src/modules/git/files/functions.bash"
  _build_repo_fixture "$BATS_TEST_TMPDIR"
  ORG="$BATS_TEST_TMPDIR/org"
}

# Run the report over the fixture. Fetching is skipped: the fixture's upstreams
# are already in the state each test asserts, and a fetch would only add the
# runtime of five subprocesses.
#
# Arguments:
#   $@ - arguments passed straight to w_git_repository_properties
_report() {
  run bash -c "source '$FUNCTIONS'; w_git_repository_properties $*"
}

# Read one field of one repository's row from the captured output.
#
# Arguments:
#   $1 - repository name, matched against the first column
#   $2 - field number: 2 branch, 3 ahead, 4 behind, 5 dirty, 6 unmerged
_field() {
  printf '%s\n' "$output" | awk -v r="$1" -v n="$2" '$1 == r { print $n; exit }'
}

@test "help: lists the options and exits 0" {
  _report --help
  (( status == 0 ))
  [[ "$output" =~ "Usage: w_git_repository_properties" ]]
  [[ "$output" =~ "--no-fetch" ]]
  [[ "$output" =~ "--branches" ]]
}

@test "target: rejects a path that is not a directory" {
  _report "$BATS_TEST_TMPDIR/org/stale/f.txt" 2>/dev/null
  (( status == 1 ))
}

@test "target: rejects an unknown option" {
  run bash -c "source '$FUNCTIONS'; w_git_repository_properties --bogus 2>&1"
  (( status == 1 ))
  [[ "$output" =~ "unknown option: --bogus" ]]
}

@test "target: requires a directory rather than defaulting to the working one" {
  run bash -c "cd '$ORG'; source '$FUNCTIONS'; w_git_repository_properties 2>&1"
  (( status == 1 ))
  [[ "$output" =~ "a directory is required" ]]
}

@test "target: reports every repository when given a relative path" {
  # The old version cd'd into each repository without returning, so with a
  # relative target every repository after the first was silently skipped.
  run bash -c "cd '$ORG'; source '$FUNCTIONS'; w_git_repository_properties . --no-fetch"
  (( status == 0 ))
  local name
  for name in ahead behind stale detached nostream; do
    printf '%s\n' "$output" | grep -qE "^${name}[[:space:]]"
  done
}

@test "target: does not treat the subdirectories of a repository as repositories" {
  # rev-parse --git-dir succeeds anywhere inside a repository, so scanning one
  # used to list every folder in it as a repository in its own right, each
  # showing the parent's state.
  mkdir -p "$ORG/stale/src" "$ORG/stale/test"
  run bash -c "source '$FUNCTIONS'; w_git_repository_properties '$ORG/stale' --no-fetch 2>&1"
  (( status == 1 ))
  [[ "$output" =~ "No git repositories" ]]
}

@test "target: skips a directory that is not a repository" {
  _report "$ORG" --no-fetch
  (( status == 0 ))
  [[ ! "$output" =~ notarepo ]]
}

@test "ahead: counts the commits the upstream does not have" {
  _report "$ORG" --no-fetch
  [[ "$(_field ahead 3)" == "2" ]]
  [[ "$(_field ahead 4)" == "0" ]]
}

@test "behind: counts the commits the upstream has and the repository does not" {
  _report "$ORG" --no-fetch
  [[ "$(_field behind 3)" == "0" ]]
  [[ "$(_field behind 4)" == "3" ]]
}

@test "upstream: a branch tracking nothing reports a dash rather than zero" {
  _report "$ORG" --no-fetch
  [[ "$(_field nostream 2)" == "orphan-work" ]]
  [[ "$(_field nostream 3)" == "-" ]]
  [[ "$(_field nostream 4)" == "-" ]]
}

@test "branch: a detached HEAD is named rather than printed as the word HEAD" {
  _report "$ORG" --no-fetch
  [[ "$(_field detached 2)" == "(detached)" ]]
}

@test "dirty: an untracked file alone marks the repository dirty" {
  _report "$ORG" --no-fetch
  [[ "$(_field detached 5)" == "yes" ]]
  [[ "$(_field stale 5)" == "no" ]]
}

@test "unmerged: counts local branches absent from the default branch" {
  _report "$ORG" --no-fetch
  [[ "$(_field stale 6)" == "2" ]]
}

@test "unmerged: leaves out the checked out branch, which ahead already covers" {
  _report "$ORG" --no-fetch
  [[ "$(_field ahead 6)" == "0" ]]
}

@test "branches: names the unmerged branches only when asked" {
  _report "$ORG" --no-fetch
  [[ ! "$output" =~ "feature/one" ]]
  _report "$ORG" --no-fetch --branches
  [[ "$output" =~ "feature/one" ]]
  [[ "$output" =~ "feature/two" ]]
}
