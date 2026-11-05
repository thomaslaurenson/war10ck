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
#   MOCK_GH_SITE  - the site data file the gh mock prints for gh api
#   CHECK_LIST    - the listing the description and topic checks run against
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
  export MOCK_GH_SITE="$REPO_ROOT/test/fixtures/gh/site_constants.js"
  CHECK_LIST="$REPO_ROOT/test/fixtures/gh/repo_metadata.json"
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
#   $2 - field number. For w_git_repository_properties: 2 branch, 3 ahead,
#        4 behind, 5 dirty, 6 unmerged. For w_git_check_descriptions: 2 chars,
#        3 words, 4 site, 5 result. For w_git_check_topics: 2 topics, 3 result
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

# Run a description or topic check against the gh mock.
#
# Arguments:
#   $1 - function to run
#   $@ - the rest, passed straight to the function
_check() {
  local fn=$1
  shift
  run env "PATH=$BIN:$PATH" "MOCK_GH_LIST=$CHECK_LIST" \
    bash -c "source '$FUNCTIONS'; $fn $*"
}

@test "check: both functions require an owner rather than defaulting to the gh account" {
  local fn
  for fn in w_git_check_descriptions w_git_check_topics; do
    _check "$fn"
    (( status == 1 ))
    [[ "$output" =~ "an owner is required" ]]
  done
  [[ ! -e "$MOCK_GH_CALLS" ]]
}

@test "check: both functions reject an unknown option" {
  local fn
  for fn in w_git_check_descriptions w_git_check_topics; do
    _check "$fn" owner --bogus
    (( status == 1 ))
    [[ "$output" =~ "unknown option: --bogus" ]]
  done
}

@test "check: both functions list only public, non-archived repositories that are not forks" {
  local fn
  for fn in w_git_check_descriptions w_git_check_topics; do
    rm -f "$MOCK_GH_CALLS"
    _check "$fn" owner
    grep -q '^repo list owner .*--no-archived' "$MOCK_GH_CALLS"
    grep -q '^repo list owner .*--source' "$MOCK_GH_CALLS"
    grep -q '^repo list owner .*--visibility public' "$MOCK_GH_CALLS"
  done
}

@test "check: every owner named is listed, and a repeated one is checked once" {
  _check w_git_check_topics owner other owner
  [[ "$(grep -c '^repo list' "$MOCK_GH_CALLS")" == "3" ]]
  grep -q '^repo list other ' "$MOCK_GH_CALLS"
  [[ "$(grep -c '^owner/good ' <<< "$output")" == "1" ]]
}

@test "check: profile repositories are skipped and named, whatever their case" {
  local fn
  for fn in w_git_check_descriptions w_git_check_topics; do
    _check "$fn" owner
    [[ -z "$(_field owner/Owner 2)" ]]
    [[ -z "$(_field owner/.github 2)" ]]
    [[ "$output" =~ "[*] Skipped profile repositories: owner/.github owner/Owner" ]]
  done
}

@test "check: a listing failure is reported and returns 1" {
  export MOCK_GH_LIST_STATUS=1
  local fn
  for fn in w_git_check_descriptions w_git_check_topics; do
    _check "$fn" nobody
    (( status == 1 ))
    [[ "$output" =~ "[!] Could not list repositories for nobody" ]]
    [[ ! "$output" =~ "Repository" ]]
  done
}

@test "check: reaching the listing limit is reported rather than passed over" {
  export MOCK_GH_LIST_FULL=1
  _check w_git_check_topics owner
  [[ "$output" =~ "[!] Listing owner stopped at 1000 repositories" ]]
  [[ "$output" =~ "Repositories passing: 0 of 1000" ]]
}

@test "descriptions: help lists the options and exits 0" {
  _check w_git_check_descriptions --help
  (( status == 0 ))
  [[ "$output" =~ "--min-chars" ]]
  [[ "$output" =~ "--no-site" ]]
  [[ ! -e "$MOCK_GH_CALLS" ]]
}

@test "descriptions: rejects a limit that is not a number" {
  _check w_git_check_descriptions owner --min-chars many
  (( status == 1 ))
  [[ "$output" =~ "--min-chars needs a number" ]]
}

@test "descriptions: rejects a minimum above the maximum" {
  _check w_git_check_descriptions owner --min-chars 200 --max-chars 100
  (( status == 1 ))
  [[ "$output" =~ "--min-chars is above --max-chars" ]]
}

@test "descriptions: passes one within the limits that matches the site" {
  _check w_git_check_descriptions owner
  [[ "$(_field owner/good 2)" == "140" ]]
  [[ "$(_field owner/good 4)" == "match" ]]
  [[ "$(_field owner/good 5)" == "pass" ]]
}

@test "descriptions: counts the words for reference" {
  _check w_git_check_descriptions owner
  [[ "$(_field owner/good 3)" == "28" ]]
  [[ "$(_field owner/empty 3)" == "0" ]]
}

@test "descriptions: one at either limit passes" {
  _check w_git_check_descriptions owner
  [[ "$(_field owner/at-min 2)" == "130" ]]
  [[ "$(_field owner/at-min 5)" == "pass" ]]
  [[ "$(_field owner/at-max 2)" == "160" ]]
  [[ "$(_field owner/at-max 5)" == "pass" ]]
}

@test "descriptions: one character either side of the limits fails" {
  _check w_git_check_descriptions owner
  [[ "$(_field owner/short 5)" == "fail" ]]
  [[ "$(_field owner/long 5)" == "fail" ]]
  [[ "$output" =~ "description is 129 characters, needs 130 to 160" ]]
  [[ "$output" =~ "description is 161 characters, needs 130 to 160" ]]
}

@test "descriptions: a repository with none fails as having none" {
  _check w_git_check_descriptions owner
  [[ "$(_field owner/empty 2)" == "0" ]]
  [[ "$(_field owner/empty 5)" == "fail" ]]
  [[ "$output" =~ "- no description" ]]
}

@test "descriptions: the limits can be changed" {
  _check w_git_check_descriptions owner --min-chars 120 --max-chars 170
  [[ "$(_field owner/short 5)" == "pass" ]]
  [[ "$(_field owner/long 5)" == "pass" ]]
}

@test "descriptions: topics are not checked" {
  _check w_git_check_descriptions owner
  [[ "$(_field owner/untagged 5)" == "pass" ]]
  [[ "$(_field owner/few-topics 5)" == "pass" ]]
  [[ ! "$output" =~ "needs at least" ]]
}

@test "descriptions: one that differs from the site fails and both are printed" {
  _check w_git_check_descriptions owner
  [[ "$(_field owner/differs 4)" == "differs" ]]
  [[ "$(_field owner/differs 5)" == "fail" ]]
  [[ "$output" =~ "description differs from the site" ]]
  [[ "$output" =~ "github: A blurb GitHub holds that the site does not" ]]
  [[ "$output" =~ "site:   A blurb the site holds that GitHub does not" ]]
}

@test "descriptions: the site's repository URL matches whatever its case, quotes unescaped" {
  _check w_git_check_descriptions owner
  [[ "$(_field owner/MixedCase 4)" == "match" ]]
  [[ "$(_field owner/MixedCase 5)" == "pass" ]]
}

@test "descriptions: a repository the site does not list is not compared" {
  _check w_git_check_descriptions owner
  [[ "$(_field owner/at-min 4)" == "-" ]]
}

@test "descriptions: site entries with no description, such as the social links, are skipped" {
  # The social links name https://github.com/owner, which would otherwise read
  # as a repository called owner missing from the listing.
  _check w_git_check_descriptions owner
  [[ ! "$output" =~ $'\n    owner\n' ]]
}

@test "descriptions: an active site project missing from the listing is reported" {
  _check w_git_check_descriptions owner
  (( status == 1 ))
  [[ "$output" =~ "On the site as active, but not a public, active repository" ]]
  [[ "$output" =~ "    owner/private" ]]
}

@test "descriptions: an archived site project, or another owner's, is not reported" {
  _check w_git_check_descriptions owner
  [[ ! "$output" =~ "owner/retired" ]]
  [[ ! "$output" =~ "other/elsewhere" ]]
}

@test "descriptions: the site's data file is read from its repository" {
  _check w_git_check_descriptions owner
  grep -q '^api .*repos/thomaslaurenson/thomaslaurenson.github.io/contents/src/data/constants.js' \
    "$MOCK_GH_CALLS"
}

@test "descriptions: --no-site makes no API call and compares nothing" {
  _check w_git_check_descriptions owner --no-site
  [[ "$(grep -c '^api' "$MOCK_GH_CALLS")" == "0" ]]
  [[ "$(_field owner/differs 4)" == "-" ]]
  [[ ! "$output" =~ "owner/private" ]]
}

@test "descriptions: a failed site fetch returns 1 and suggests --no-site" {
  export MOCK_GH_API_STATUS=1
  _check w_git_check_descriptions owner
  (( status == 1 ))
  [[ "$output" =~ "[!] Could not read src/data/constants.js" ]]
  [[ "$output" =~ "--no-site" ]]
  [[ ! "$output" =~ "Repository" ]]
}

@test "descriptions: a site data file with no projects fails rather than passing everything" {
  # A layout the reader no longer understands yields no projects, which would
  # otherwise leave every repository with nothing to differ from.
  export MOCK_GH_SITE="$BATS_TEST_TMPDIR/empty.js"
  printf 'export const projects = [];\n' > "$MOCK_GH_SITE"
  _check w_git_check_descriptions owner
  (( status == 1 ))
  [[ "$output" =~ "Found no projects in src/data/constants.js" ]]
}

@test "descriptions: the status is 0 when every repository passes" {
  CHECK_LIST="$REPO_ROOT/test/fixtures/gh/repo_metadata_clean.json"
  _check w_git_check_descriptions owner --no-site
  (( status == 0 ))
  [[ "$output" =~ "[*] Repositories passing: 3 of 3" ]]
  [[ ! "$output" =~ "[!]" ]]
}

@test "descriptions: the status is 1 and the count says so when any repository fails" {
  _check w_git_check_descriptions owner
  (( status == 1 ))
  [[ "$output" =~ "[*] Repositories passing: 6 of 10" ]]
}

@test "topics: help lists the options and exits 0" {
  _check w_git_check_topics --help
  (( status == 0 ))
  [[ "$output" =~ "--min-topics" ]]
  [[ ! -e "$MOCK_GH_CALLS" ]]
}

@test "topics: rejects a minimum that is not a number" {
  _check w_git_check_topics owner --min-topics many
  (( status == 1 ))
  [[ "$output" =~ "--min-topics needs a number" ]]
}

@test "topics: passes a repository with enough, and names them" {
  _check w_git_check_topics owner
  [[ "$(_field owner/good 2)" == "3" ]]
  [[ "$(_field owner/good 3)" == "pass" ]]
  [[ "$output" =~ "pass    one, two, three" ]]
}

@test "topics: too few fails, and none at all reads as zero" {
  # gh reports a repository with no topics as null rather than an empty list
  _check w_git_check_topics owner
  [[ "$(_field owner/untagged 2)" == "0" ]]
  [[ "$(_field owner/untagged 3)" == "fail" ]]
  [[ "$(_field owner/untagged 4)" == "-" ]]
  [[ "$(_field owner/few-topics 3)" == "fail" ]]
  [[ "$output" =~ "needs at least 3 topics, has 0" ]]
  [[ "$output" =~ "needs at least 3 topics, has 2" ]]
}

@test "topics: the minimum can be changed" {
  _check w_git_check_topics owner --min-topics 2
  [[ "$(_field owner/few-topics 3)" == "pass" ]]
}

@test "topics: descriptions are not checked and the site is not read" {
  _check w_git_check_topics owner
  [[ "$(_field owner/empty 3)" == "pass" ]]
  [[ "$(grep -c '^api' "$MOCK_GH_CALLS")" == "0" ]]
}

@test "topics: the status is 0 when every repository passes" {
  CHECK_LIST="$REPO_ROOT/test/fixtures/gh/repo_metadata_clean.json"
  _check w_git_check_topics owner
  (( status == 0 ))
  [[ "$output" =~ "[*] Repositories passing: 3 of 3" ]]
}

@test "topics: the status is 1 and the count says so when any repository fails" {
  _check w_git_check_topics owner
  (( status == 1 ))
  [[ "$output" =~ "[*] Repositories passing: 8 of 10" ]]
}
