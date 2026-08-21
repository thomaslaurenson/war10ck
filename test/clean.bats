bats_require_minimum_version 1.7.0

load helpers/common

# Configure the environment before each test.
#
# Environment:
#   REPO_ROOT - absolute path to the repository root
#   LIB       - the clean library under test
#   PUBLIC    - public helpers, which clean depends on
setup() {
  REPO_ROOT="$(_repo_root)"
  LIB="$REPO_ROOT/src/lib/clean.sh"
  PUBLIC="$REPO_ROOT/src/lib/public.sh"
}

# Source the clean library with HOME pointed at a scratch directory, so the
# catalogue resolves against a fixture tree instead of the real home.
#
# Arguments:
#   $1   - the HOME to use
#   $2.. - shell code to run once loaded
_with_home() {
  local home=$1; shift
  HOME="$home" bash -c "source '$PUBLIC'; source '$LIB'; $*"
}

# Print every $HOME-relative path the current modules actually write, one per
# line. Module scripts spell paths through per-module variables
# (WAR10CK_DIR="$HOME/.war10ck", then "$WAR10CK_DIR/.aliases"), so the
# assignments are collected first and substituted back in - comparing raw text
# would treat ~/.aliases and ~/.war10ck/.aliases as the same path.
#
# Lines calling a w_remove_* helper are skipped: naming a path in order to
# delete it is not writing it, and the bash module deliberately removes a
# catalogued path (functions.d/sshfs) on upgrade.
_live_module_paths() {
  local f line var val path
  for f in "$REPO_ROOT"/src/modules/*/*.sh; do
    local -A vars=()
    while IFS= read -r line; do
      var=${line%%=*}
      val=${line#*=}; val=${val#\"}; val=${val%\"}
      val=${val/\$\{HOME\}/\$HOME}
      vars[$var]=$val
    done < <(grep -oE '^[A-Za-z_][A-Za-z0-9_]*="\$\{?HOME\}?/[^"]*"' "$f")

    while IFS= read -r path; do
      path=${path//\"/}
      path=${path/\$\{HOME\}/\$HOME}
      if [[ "$path" =~ ^\$([A-Za-z_][A-Za-z0-9_]*)(/.*)?$ ]]; then
        var=${BASH_REMATCH[1]}
        [[ -n "${vars[$var]:-}" ]] && path="${vars[$var]}${BASH_REMATCH[2]:-}"
      fi
      [[ "$path" == '$HOME'/* ]] && printf '%s\n' "${path#\$HOME/}"
    done < <(grep -vE 'w_remove_' "$f" \
               | grep -oE '"\$\{?[A-Za-z_][A-Za-z0-9_]*\}?/[^"]*"')

    # w_deploy_functions <module> writes ~/.war10ck/functions.d/<module>
    while IFS= read -r line; do
      printf '.war10ck/functions.d/%s\n' "${line##* }"
    done < <(grep -oE 'w_deploy_functions +[A-Za-z0-9_-]+' "$f")
    unset vars
  done
}

@test "catalogue: no entry collides with a path the current version writes" {
  # The one invariant that keeps clean safe. Several live paths look exactly
  # like dead ones (~/.tmux.conf, ~/.war10ck/.aliases, ~/ramdisk), so a future
  # refactor could reintroduce a catalogued path without anyone noticing.
  local -a live=()
  mapfile -t live < <(_live_module_paths | sort -u)
  (( ${#live[@]} > 10 ))   # the extractor found something; guards against a silent no-op

  local -a offenders=()
  local path suffix l
  while IFS='|' read -r _ path _; do
    [[ -n "$path" ]] || continue
    suffix=${path#/fixture-home/}
    for l in "${live[@]}"; do
      [[ "$l" == "$suffix" ]] && offenders+=("$suffix")
    done
  done < <(HOME=/fixture-home bash -c "source '$LIB'; printf '%s\n' \"\${W_CLEAN_ENTRIES[@]}\"")

  [[ ${#offenders[@]} -eq 0 ]] || printf 'catalogued but still live: %s\n' "${offenders[*]}"
  (( ${#offenders[@]} == 0 ))
}

@test "catalogue: every entry is a HOME path, never a system path" {
  run bash -c "HOME=/fixture-home; source '$LIB'; printf '%s\n' \"\${W_CLEAN_ENTRIES[@]}\""
  (( status == 0 ))
  while IFS='|' read -r _ path _; do
    [[ "$path" == /fixture-home/* ]]
  done <<< "$output"
}

@test "report: says nothing to clean on a home with no artefacts" {
  run _with_home "$BATS_TEST_TMPDIR/empty" "clean"
  (( status == 0 ))
  [[ "$output" =~ "Nothing to clean" ]]
}

@test "report: lists a found artefact and does not remove it" {
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h"
  printf 'stale\n' > "$h/.functions"
  run _with_home "$h" "clean"
  (( status == 0 ))
  [[ "$output" =~ "~/.functions" ]]
  [[ "$output" =~ "--apply" ]]
  [[ -f "$h/.functions" ]]
}

@test "apply: removes a catalogued file" {
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h/.war10ck"
  printf 'stale\n' > "$h/.war10ck/.commands"
  run _with_home "$h" "clean --apply"
  (( status == 0 ))
  [[ ! -f "$h/.war10ck/.commands" ]]
}

@test "apply: removes an empty catalogued directory but keeps a non-empty one" {
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h/.config/i3/layouts" "$h/.config/i3/scripts"
  printf 'mine\n' > "$h/.config/i3/scripts/my-own.sh"
  run _with_home "$h" "clean --apply"
  (( status == 0 ))
  [[ ! -d "$h/.config/i3/layouts" ]]
  [[ -d "$h/.config/i3/scripts" ]]
  [[ -f "$h/.config/i3/scripts/my-own.sh" ]]
}

@test "apply: clears a directory by removing its catalogued contents first" {
  # ~/.tmux/cer and homelab are listed before ~/.tmux, so the directory is
  # empty by the time the pass reaches it.
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h/.tmux"
  printf 'x\n' > "$h/.tmux/cer"
  printf 'x\n' > "$h/.tmux/homelab"
  run _with_home "$h" "clean --apply"
  (( status == 0 ))
  [[ ! -d "$h/.tmux" ]]
}

@test "apply: never removes an uncatalogued file living beside a stale one" {
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h/.war10ck/functions.d"
  printf 'old\n' > "$h/.war10ck/functions.d/sshfs"
  printf 'live\n' > "$h/.war10ck/functions.d/github"
  run _with_home "$h" "clean --apply"
  (( status == 0 ))
  [[ ! -f "$h/.war10ck/functions.d/sshfs" ]]
  [[ -f "$h/.war10ck/functions.d/github" ]]
}

@test "mount guard: a non-empty ~/sshfs is left alone" {
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h/sshfs/somehost"
  run _with_home "$h" "clean --apply"
  (( status == 0 ))
  [[ -d "$h/sshfs/somehost" ]]
}

@test "bashrc: a block is reported with its line numbers and content" {
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h"
  printf 'export A=1\n\n# CUSTOM ALIASES\nif [ -f ~/.aliases ]; then\n    . ~/.aliases\nfi\n' > "$h/.bashrc"
  run _with_home "$h" "clean"
  (( status == 0 ))
  [[ "$output" =~ "lines 3-6" ]]
  [[ "$output" =~ "CUSTOM ALIASES" ]]
  # Reporting must not touch the file
  [[ $(wc -l < "$h/.bashrc") -eq 6 ]]
}

@test "bashrc: declining the prompt leaves the file untouched" {
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h"
  printf '# CUSTOM ALIASES\nif [ -f ~/.aliases ]; then\n    . ~/.aliases\nfi\n' > "$h/.bashrc"
  run bash -c "printf 'n\n' | HOME='$h' bash -c \"source '$PUBLIC'; source '$LIB'; clean --apply\""
  (( status == 0 ))
  [[ $(wc -l < "$h/.bashrc") -eq 4 ]]
  [[ ! -f "$h/.bashrc.war10ck-bak" ]]
}

@test "bashrc: accepting the prompt removes the block and leaves a backup" {
  local h="$BATS_TEST_TMPDIR/h"
  mkdir -p "$h"
  printf 'export KEEP=1\n# CUSTOM ALIASES\nif [ -f ~/.aliases ]; then\n    . ~/.aliases\nfi\nexport ALSO_KEEP=1\n' > "$h/.bashrc"
  run bash -c "printf 'y\n' | HOME='$h' bash -c \"source '$PUBLIC'; source '$LIB'; clean --apply\""
  (( status == 0 ))
  run cat "$h/.bashrc"
  [[ "$output" == "export KEEP=1
export ALSO_KEEP=1" ]]
  [[ -f "$h/.bashrc.war10ck-bak" ]]
}

@test "w_block_range: refuses a block whose end pattern never matches" {
  # Without this guard a /start/,/end/ sed would delete to end of file.
  local f="$BATS_TEST_TMPDIR/rc"
  printf '# CUSTOM ALIASES\nif [ -f x ]; then\n    . x\n' > "$f"
  run bash -c "source '$PUBLIC'; w_block_range '$f' '^# CUSTOM ALIASES\$' '^fi\$'"
  (( status == 0 ))
  [[ -z "$output" ]]
}

@test "clean: rejects an unknown option" {
  run _with_home "$BATS_TEST_TMPDIR/h" "clean --nuke-everything"
  (( status == 1 ))
  [[ "$output" =~ "Unknown clean option" ]]
}
