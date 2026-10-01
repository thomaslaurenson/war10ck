bats_require_minimum_version 1.7.0

load helpers/common

# Exercise w_git_repository_properties against repositories in known states, and
# the repository feature functions against a gh mock.
#
# The states are built rather than asserted against whatever the host happens to
# hold, because the two bugs w_git_repository_properties used to carry (ahead
# and behind reporting each other's value, and a relative target reporting only
# the first repository) both produce plausible looking output. Only a fixture
# with a known answer catches them.
#
# Environment:
#   REPO_ROOT     - absolute path to the repository root, derived from BATS_TEST_DIRNAME
#   FUNCTIONS     - path to the sourced functions file under test
#   ORG           - the fixture directory of repositories
#   BIN           - PATH directory holding the gh mock
#   MOCK_GH_CALLS - file the gh mock records each call in
#   MOCK_GH_LIST  - the repository listing the gh mock prints
setup() {
  REPO_ROOT="$(_repo_root)"
  FUNCTIONS="$REPO_ROOT/src/modules/git/files/functions.bash"
  _build_repo_fixture "$BATS_TEST_TMPDIR"
  ORG="$BATS_TEST_TMPDIR/org"
  BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BIN"
  ln -sf "$REPO_ROOT/test/helpers/mock_gh" "$BIN/gh"
  export MOCK_GH_CALLS="$BATS_TEST_TMPDIR/gh_calls"
  export MOCK_GH_LIST="$REPO_ROOT/test/fixtures/gh/repo_list.json"
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

# Run a repository feature function against the gh mock, answering its prompts.
#
# Arguments:
#   $1 - function to run
#   $2 - the lines typed at the prompts, the owner name first and the reply to
#        the confirmation second
_disable() {
  run env "PATH=$BIN:$PATH" bash -c "source '$FUNCTIONS'; $1" <<< "$2"
}

# The non-ASCII bytes in a string, so an assertion can require there are none.
#
# Arguments:
#   $1 - the string to check
# Outputs:
#   every byte of $1 outside the ASCII range, on stdout
_non_ascii() {
  LC_ALL=C tr -d '\000-\177' <<< "$1"
}

@test "disable_wiki: edits only the repositories with the wiki on" {
  _disable w_git_disable_wiki_for_user $'owner\ny'
  (( status == 0 ))
  [[ "$output" =~ "Repositories with wiki on: 2 of 5" ]]
  [[ "$output" =~ "[~] Disabled wiki: owner/both" ]]
  [[ "$output" =~ "[~] Disabled wiki: owner/wiki-only" ]]
  [[ "$(grep -c '^repo edit' "$MOCK_GH_CALLS")" == "2" ]]
  grep -qx 'repo edit owner/both --enable-wiki=false' "$MOCK_GH_CALLS"
  grep -qx 'repo edit owner/wiki-only --enable-wiki=false' "$MOCK_GH_CALLS"
}

@test "disable_project: edits only the repositories with projects on" {
  _disable w_git_disable_project_for_user $'owner\ny'
  (( status == 0 ))
  [[ "$output" =~ "Repositories with projects on: 2 of 5" ]]
  [[ "$output" =~ "[~] Disabled projects: owner/both" ]]
  [[ "$output" =~ "[~] Disabled projects: owner/projects-only" ]]
  [[ "$(grep -c '^repo edit' "$MOCK_GH_CALLS")" == "2" ]]
  grep -qx 'repo edit owner/both --enable-projects=false' "$MOCK_GH_CALLS"
  grep -qx 'repo edit owner/projects-only --enable-projects=false' "$MOCK_GH_CALLS"
}

@test "disable_discussions: edits only the repositories with discussions on" {
  _disable w_git_disable_discussions_for_user $'owner\ny'
  (( status == 0 ))
  [[ "$output" =~ "Repositories with discussions on: 1 of 5" ]]
  [[ "$output" =~ "[~] Disabled discussions: owner/discussions-only" ]]
  [[ "$(grep -c '^repo edit' "$MOCK_GH_CALLS")" == "1" ]]
  grep -qx 'repo edit owner/discussions-only --enable-discussions=false' "$MOCK_GH_CALLS"
}

@test "disable: lists the named owner's non-archived repositories" {
  _disable w_git_disable_wiki_for_user $'owner\nn'
  (( status == 0 ))
  grep -q '^repo list owner .*--no-archived' "$MOCK_GH_CALLS"
}

@test "disable: prints only ASCII, though gh prints a tick on every edit" {
  # Pins the mock first: if it stopped printing the tick, the assertion on the
  # function's output below would pass without testing anything.
  run env "PATH=$BIN:$PATH" gh repo edit owner/both --enable-wiki=false
  [[ -n "$(_non_ascii "$output")" ]]

  _disable w_git_disable_wiki_for_user $'owner\ny'
  (( status == 0 ))
  [[ "$output" =~ "Disabled wiki" ]]
  [[ -z "$(_non_ascii "$output")" ]]
}

@test "disable: an empty name is rejected before gh is called" {
  # gh reads an empty owner as the authenticated account, so passing it through
  # would edit every repository that account owns.
  _disable w_git_disable_wiki_for_user $'\ny'
  (( status == 1 ))
  [[ "$output" =~ "[!] Name cannot be empty" ]]
  [[ ! -e "$MOCK_GH_CALLS" ]]
}

@test "disable: a refusal at the prompt edits nothing" {
  _disable w_git_disable_wiki_for_user $'owner\nn'
  (( status == 0 ))
  [[ "$output" =~ "owner/both" ]]
  [[ "$output" =~ "Aborted" ]]
  [[ "$(grep -c '^repo edit' "$MOCK_GH_CALLS")" == "0" ]]
}

@test "disable: an empty reply at the prompt edits nothing" {
  _disable w_git_disable_wiki_for_user $'owner\n'
  (( status == 0 ))
  [[ "$output" =~ "Aborted" ]]
  [[ "$(grep -c '^repo edit' "$MOCK_GH_CALLS")" == "0" ]]
}

@test "disable: a failed edit is reported, the rest still run, and the status is 1" {
  export MOCK_GH_EDIT_FAIL=owner/both
  _disable w_git_disable_wiki_for_user $'owner\ny'
  (( status == 1 ))
  [[ "$output" =~ "[!] Could not disable wiki: owner/both" ]]
  [[ "$output" =~ "HTTP 403" ]]
  [[ "$output" =~ "[~] Disabled wiki: owner/wiki-only" ]]
  [[ "$output" =~ "[!] Repositories not changed: 1 of 2" ]]
}

@test "disable: a listing failure is reported and returns 1" {
  export MOCK_GH_LIST_STATUS=1
  _disable w_git_disable_wiki_for_user $'nobody\ny'
  (( status == 1 ))
  [[ "$output" =~ "[!] Could not list repositories for nobody" ]]
  [[ "$(grep -c '^repo edit' "$MOCK_GH_CALLS")" == "0" ]]
}

@test "disable: reaching the listing limit is reported rather than passed over" {
  # gh stops at the limit silently, so an owner with more repositories than it
  # looks exactly like one with that many unless the count is checked.
  export MOCK_GH_LIST_FULL=1
  _disable w_git_disable_wiki_for_user $'owner\ny'
  (( status == 0 ))
  [[ "$output" =~ "[!] Listing stopped at 1000 repositories" ]]
  [[ "$output" =~ "Repositories with wiki on: 0 of 1000" ]]
  [[ "$(grep -c '^repo edit' "$MOCK_GH_CALLS")" == "0" ]]
}
