bats_require_minimum_version 1.7.0

load helpers/common

# Configure the environment before each test.
#
# Environment:
#   REPO_ROOT - absolute path to the repository root
setup() {
  REPO_ROOT="$(_repo_root)"
}

# Print the files the lint target passes to shellcheck, one per line. Read from
# a dry run rather than from the Makefile source, so the test sees the list make
# actually builds rather than the expression that builds it.
_lint_file_list() {
  make -n -C "$REPO_ROOT" lint 2>/dev/null \
    | grep -E '^shellcheck ' \
    | tr ' ' '\n' \
    | grep -vE '^(shellcheck|-s|bash)$' \
    | sort -u
}

@test "lint: every shell script in the repository is checked" {
  # The list was once built with src/modules/**/*.sh. Without globstar, which
  # is not set in a recipe, ** collapses to * and the pattern stops one level
  # down, silently skipping every deployed file under src/modules/*/files.
  local -a linted=() present=() missing=()
  mapfile -t linted < <(_lint_file_list)
  mapfile -t present < <(cd "$REPO_ROOT" \
    && find src test -type f \( -name '*.sh' -o -name '*.bash' \) \
         -not -path 'test/extern/*' | sort)

  (( ${#present[@]} > 50 ))

  local f
  for f in "${present[@]}"; do
    printf '%s\n' "${linted[@]}" | grep -qxF "$f" || missing+=("$f")
  done
  [[ ${#missing[@]} -eq 0 ]] || printf 'not linted: %s\n' "${missing[*]}"
  (( ${#missing[@]} == 0 ))
}

@test "lint: the sourced fragments with no extension are checked" {
  # These have no extension and no shebang because rundmc sources them, so no
  # find by name or by shebang will discover them. They are also the files most
  # worth checking: a quoting bug in them lands in every interactive shell.
  local -a linted=()
  mapfile -t linted < <(_lint_file_list)

  local f
  for f in src/modules/bash/files/rundmc \
           src/modules/bash/files/aliases \
           src/modules/bash/files/environment \
           src/modules/bash/files/history \
           src/modules/bash/files/functions.d/general \
           src/modules/bash/files/functions.d/github; do
    printf '%s\n' "${linted[@]}" | grep -qxF "$f"
  done
}

@test "lint: the file list contains no unexpanded glob" {
  # A literal * reaching shellcheck means make passed a pattern through rather
  # than a path, which fails open: shellcheck reports nothing for a file that
  # does not exist under that name.
  run _lint_file_list
  (( status == 0 ))
  [[ ! "$output" =~ \* ]]
}

@test "check_version: passes when the changelog leads with the embedded version" {
  run make --no-print-directory -C "$REPO_ROOT" check_version
  (( status == 0 ))
  [[ "$output" =~ ok$ ]]
}

@test "check_version: fails when the changelog leads with a different version" {
  # A copy of the tree, because the target reads CHANGELOG.md from the working
  # directory and the test must not edit the repository's own copy.
  local work="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$work/src/lib" "$work/test"
  cp "$REPO_ROOT/Makefile" "$work/Makefile"
  cp "$REPO_ROOT/src/lib/version.sh" "$work/src/lib/version.sh"
  sed -E '0,/^## [0-9]+\.[0-9]+\.[0-9]+ /s//## 99.99.99 /' \
    "$REPO_ROOT/CHANGELOG.md" > "$work/CHANGELOG.md"

  run make --no-print-directory -C "$work" check_version
  (( status != 0 ))
  [[ "$output" =~ "CHANGELOG.md leads with 99.99.99" ]]
}
