bats_require_minimum_version 1.7.0

load helpers/common

# Configure the environment before each test.
#
# Environment:
#   REPO_ROOT - absolute path to the repository root, derived from BATS_TEST_DIRNAME
#   LIB       - path to the sourced library under test
setup() {
  REPO_ROOT="$(_repo_root)"
  LIB="$REPO_ROOT/src/lib/public.sh"
}

@test "w_log_info: writes the message to stdout" {
  run bash -c "source '$LIB'; w_log_info 'hello'"
  (( status == 0 ))
  [[ "$output" == "[*] hello" ]]
}

@test "w_log_error: writes the message to stderr" {
  run bash -c "source '$LIB'; w_log_error 'boom' 2>&1 1>/dev/null"
  (( status == 0 ))
  [[ "$output" == "[!] boom" ]]
}

@test "w_log_debug: prints nothing when WAR10CK_DEBUG is unset" {
  run bash -c "source '$LIB'; w_log_debug 'quiet'"
  (( status == 0 ))
  [[ -z "$output" ]]
}

@test "w_log_debug: prints when WAR10CK_DEBUG is 1" {
  run bash -c "export WAR10CK_DEBUG=1; source '$LIB'; w_log_debug 'loud'"
  (( status == 0 ))
  [[ "$output" == "[d] loud" ]]
}

@test "w_log_debug: returns 0 so it is safe under set -e" {
  run bash -c "set -e; source '$LIB'; w_log_debug 'quiet'; printf 'reached\n'"
  (( status == 0 ))
  [[ "$output" == "reached" ]]
}

@test "w_q: suppresses command output in normal mode" {
  run bash -c "source '$LIB'; w_q printf 'noisy\n'"
  (( status == 0 ))
  [[ -z "$output" ]]
}

@test "w_q: streams command output in debug mode" {
  run bash -c "export WAR10CK_DEBUG=1; source '$LIB'; w_q printf 'noisy\n'"
  (( status == 0 ))
  [[ "$output" == "noisy" ]]
}

@test "w_is_installed: returns 0 for a command on PATH" {
  run bash -c "source '$LIB'; w_is_installed bash"
  (( status == 0 ))
}

@test "w_is_installed: returns 1 for a missing command" {
  run bash -c "source '$LIB'; w_is_installed definitely_not_a_real_command"
  (( status != 0 ))
}

@test "w_deploy_file: copies the file and creates the parent directory" {
  printf 'content\n' > "$BATS_TEST_TMPDIR/src.txt"
  run bash -c "
    source '$LIB'
    w_deploy_file '$BATS_TEST_TMPDIR/src.txt' '$BATS_TEST_TMPDIR/nested/deep/out.txt'
  "
  (( status == 0 ))
  [[ "$(cat "$BATS_TEST_TMPDIR/nested/deep/out.txt")" == "content" ]]
}

@test "w_deploy_dir: copies a directory tree recursively" {
  mkdir -p "$BATS_TEST_TMPDIR/from/sub"
  printf 'a\n' > "$BATS_TEST_TMPDIR/from/sub/a.txt"
  run bash -c "
    source '$LIB'
    w_deploy_dir '$BATS_TEST_TMPDIR/from' '$BATS_TEST_TMPDIR/to'
  "
  (( status == 0 ))
  [[ "$(cat "$BATS_TEST_TMPDIR/to/sub/a.txt")" == "a" ]]
}

@test "w_make_executable: sets the executable bit" {
  printf '#!/usr/bin/env bash\n' > "$BATS_TEST_TMPDIR/s.sh"
  run bash -c "source '$LIB'; w_make_executable '$BATS_TEST_TMPDIR/s.sh'"
  (( status == 0 ))
  [[ -x "$BATS_TEST_TMPDIR/s.sh" ]]
}

@test "w_remove_file: removes an existing file" {
  printf 'x\n' > "$BATS_TEST_TMPDIR/gone.txt"
  run bash -c "source '$LIB'; w_remove_file '$BATS_TEST_TMPDIR/gone.txt'"
  (( status == 0 ))
  [[ ! -f "$BATS_TEST_TMPDIR/gone.txt" ]]
  [[ "$output" =~ "Removed" ]]
}

@test "w_remove_file: succeeds quietly when the file is absent" {
  run bash -c "source '$LIB'; w_remove_file '$BATS_TEST_TMPDIR/never.txt'"
  (( status == 0 ))
  [[ -z "$output" ]]
}

@test "w_remove_dir: removes an existing directory" {
  mkdir -p "$BATS_TEST_TMPDIR/d/sub"
  run bash -c "source '$LIB'; w_remove_dir '$BATS_TEST_TMPDIR/d'"
  (( status == 0 ))
  [[ ! -d "$BATS_TEST_TMPDIR/d" ]]
}

@test "w_symlink: creates a link and replaces an existing one" {
  printf 'target\n' > "$BATS_TEST_TMPDIR/target.txt"
  run bash -c "
    source '$LIB'
    w_symlink '$BATS_TEST_TMPDIR/target.txt' '$BATS_TEST_TMPDIR/link'
    w_symlink '$BATS_TEST_TMPDIR/target.txt' '$BATS_TEST_TMPDIR/link'
  "
  (( status == 0 ))
  [[ -L "$BATS_TEST_TMPDIR/link" ]]
  [[ "$(cat "$BATS_TEST_TMPDIR/link")" == "target" ]]
}

@test "w_remove_symlink: removes a symlink but leaves a regular file alone" {
  printf 'keep\n' > "$BATS_TEST_TMPDIR/regular.txt"
  ln -s "$BATS_TEST_TMPDIR/regular.txt" "$BATS_TEST_TMPDIR/link"
  run bash -c "
    source '$LIB'
    w_remove_symlink '$BATS_TEST_TMPDIR/link'
    w_remove_symlink '$BATS_TEST_TMPDIR/regular.txt'
  "
  (( status == 0 ))
  [[ ! -L "$BATS_TEST_TMPDIR/link" ]]
  [[ -f "$BATS_TEST_TMPDIR/regular.txt" ]]
}

@test "w_verify_sha256: exits 0 on a matching hash" {
  printf 'payload\n' > "$BATS_TEST_TMPDIR/f.txt"
  local expected
  expected=$(sha256sum "$BATS_TEST_TMPDIR/f.txt" | cut -d' ' -f1)
  run bash -c "source '$LIB'; w_verify_sha256 '$BATS_TEST_TMPDIR/f.txt' '$expected'"
  (( status == 0 ))
  [[ "$output" =~ "Checksum OK" ]]
}

@test "w_verify_sha256: returns 1 and reports both hashes on mismatch" {
  printf 'payload\n' > "$BATS_TEST_TMPDIR/f.txt"
  run bash -c "source '$LIB'; w_verify_sha256 '$BATS_TEST_TMPDIR/f.txt' 'deadbeef' 2>&1"
  (( status == 1 ))
  [[ "$output" =~ "Checksum mismatch" ]]
  [[ "$output" =~ "expected" ]]
  [[ "$output" =~ "actual" ]]
}

@test "w_verify_sha256: does not delete the file on mismatch" {
  printf 'payload\n' > "$BATS_TEST_TMPDIR/f.txt"
  run bash -c "source '$LIB'; w_verify_sha256 '$BATS_TEST_TMPDIR/f.txt' 'deadbeef' 2>&1"
  (( status == 1 ))
  [[ -f "$BATS_TEST_TMPDIR/f.txt" ]]
}

# The complete "every defined w_ is also exported" invariant is asserted in
# modules.bats. This complements it by exercising the runtime property that
# export -f actually buys: a helper resolving inside a fresh child shell, which
# is how module scripts (run as 'bash <script>') reach the API.
@test "public API: exported functions are callable from a child shell" {
  run bash -c "
    source '$LIB'
    bash -c 'w_log_info from-child'
  "
  (( status == 0 ))
  [[ "$output" == "[*] from-child" ]]
}

@test "w_deploy_file: handles paths containing spaces" {
  mkdir -p "$BATS_TEST_TMPDIR/dir with space"
  printf 'spaced\n' > "$BATS_TEST_TMPDIR/dir with space/in.txt"
  run bash -c "
    source '$LIB'
    w_deploy_file '$BATS_TEST_TMPDIR/dir with space/in.txt' '$BATS_TEST_TMPDIR/out dir/out.txt'
  "
  (( status == 0 ))
  [[ "$(cat "$BATS_TEST_TMPDIR/out dir/out.txt")" == "spaced" ]]
}

@test "w_sudo_remove_file: removes an existing file" {
  _stub_sudo "$BATS_TEST_TMPDIR/bin"
  printf 'x\n' > "$BATS_TEST_TMPDIR/f.txt"
  run bash -c "
    PATH='$BATS_TEST_TMPDIR/bin:$PATH'
    source '$LIB'
    w_sudo_remove_file '$BATS_TEST_TMPDIR/f.txt'
  "
  (( status == 0 ))
  [[ ! -f "$BATS_TEST_TMPDIR/f.txt" ]]
}

@test "w_sudo_remove_file: succeeds quietly when the file is absent" {
  _stub_sudo "$BATS_TEST_TMPDIR/bin"
  run bash -c "
    PATH='$BATS_TEST_TMPDIR/bin:$PATH'
    source '$LIB'
    w_sudo_remove_file '$BATS_TEST_TMPDIR/never.txt'
  "
  (( status == 0 ))
  [[ -z "$output" ]]
}

@test "w_sudo_remove_dir: removes an existing directory tree" {
  _stub_sudo "$BATS_TEST_TMPDIR/bin"
  mkdir -p "$BATS_TEST_TMPDIR/d/sub"
  run bash -c "
    PATH='$BATS_TEST_TMPDIR/bin:$PATH'
    source '$LIB'
    w_sudo_remove_dir '$BATS_TEST_TMPDIR/d'
  "
  (( status == 0 ))
  [[ ! -d "$BATS_TEST_TMPDIR/d" ]]
}

@test "w_sudo_remove_symlink: removes a symlink but leaves a regular file" {
  _stub_sudo "$BATS_TEST_TMPDIR/bin"
  printf 'keep\n' > "$BATS_TEST_TMPDIR/regular.txt"
  ln -s "$BATS_TEST_TMPDIR/regular.txt" "$BATS_TEST_TMPDIR/link"
  run bash -c "
    PATH='$BATS_TEST_TMPDIR/bin:$PATH'
    source '$LIB'
    w_sudo_remove_symlink '$BATS_TEST_TMPDIR/link'
    w_sudo_remove_symlink '$BATS_TEST_TMPDIR/regular.txt'
  "
  (( status == 0 ))
  [[ ! -L "$BATS_TEST_TMPDIR/link" ]]
  [[ -f "$BATS_TEST_TMPDIR/regular.txt" ]]
}

@test "w_sudo_symlink: creates a link and its parent directory" {
  _stub_sudo "$BATS_TEST_TMPDIR/bin"
  printf 'target\n' > "$BATS_TEST_TMPDIR/target.txt"
  run bash -c "
    PATH='$BATS_TEST_TMPDIR/bin:$PATH'
    source '$LIB'
    w_sudo_symlink '$BATS_TEST_TMPDIR/target.txt' '$BATS_TEST_TMPDIR/nested/link'
  "
  (( status == 0 ))
  [[ -L "$BATS_TEST_TMPDIR/nested/link" ]]
  [[ "$(cat "$BATS_TEST_TMPDIR/nested/link")" == "target" ]]
}

@test "w_remove_lines: deletes only the matching lines" {
  cat > "$BATS_TEST_TMPDIR/rc" <<'RC'
export KEEP_ONE=1
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
export KEEP_TWO=1
RC
  run bash -c "source '$LIB'; w_remove_lines '$BATS_TEST_TMPDIR/rc' 'NVM_DIR'"
  (( status == 0 ))
  grep -q 'KEEP_ONE=1' "$BATS_TEST_TMPDIR/rc"
  grep -q 'KEEP_TWO=1' "$BATS_TEST_TMPDIR/rc"
  ! grep -q 'NVM_DIR' "$BATS_TEST_TMPDIR/rc"
}

@test "w_remove_lines: succeeds when the file does not exist" {
  run bash -c "source '$LIB'; w_remove_lines '$BATS_TEST_TMPDIR/nofile' 'PATTERN'"
  (( status == 0 ))
}

@test "w_remove_lines: leaves a file with no match untouched" {
  printf 'export KEEP=1\n' > "$BATS_TEST_TMPDIR/rc"
  run bash -c "source '$LIB'; w_remove_lines '$BATS_TEST_TMPDIR/rc' 'NVM_DIR'"
  (( status == 0 ))
  [[ "$(cat "$BATS_TEST_TMPDIR/rc")" == "export KEEP=1" ]]
}

@test "w_apt_remove_key: removes the keyring file for the named source" {
  # The keyring lives under /etc, which the test cannot write to, so the removal
  # delegate is captured instead: what matters is the name -> keyfile-path
  # mapping and that removal is routed through the sudo helper, not a raw rm.
  run bash -c "
    source '$LIB'
    w_sudo_remove_file() { printf 'remove:%s\n' \"\$1\"; }
    w_apt_remove_key docker
  "
  (( status == 0 ))
  [[ "$output" == "remove:/etc/apt/keyrings/docker.gpg" ]]
}

@test "w_download: fetches via curl when curl is available" {
  printf 'payload\n' > "$BATS_TEST_TMPDIR/remote.txt"
  run bash -c "
    source '$LIB'
    w_download 'file://$BATS_TEST_TMPDIR/remote.txt' '$BATS_TEST_TMPDIR/got.txt'
  "
  (( status == 0 ))
  [[ "$(cat "$BATS_TEST_TMPDIR/got.txt")" == "payload" ]]
}

@test "w_download: falls back to wget when curl is absent" {
  # wget does not support file:// URLs, so a stub stands in for the transfer.
  # What is under test is the branch selection: with no curl on PATH,
  # w_download must reach for wget and pass it the -O destination.
  local stub="$BATS_TEST_TMPDIR/stub"
  _link_tools "$stub" bash sed grep cut awk cat mktemp rm mv cp mkdir dirname basename chmod
  cat > "$stub/wget" <<'WGET'
#!/usr/bin/env bash
# Invoked as: wget -q -O <dest> <url>
printf 'viawget\n' > "$3"
WGET
  chmod +x "$stub/wget"

  run bash -c "
    PATH='$stub'
    source '$LIB'
    command -v curl >/dev/null && exit 90
    w_download 'https://example.com/thing' '$BATS_TEST_TMPDIR/got.txt'
  "
  (( status == 0 ))
  [[ "$(cat "$BATS_TEST_TMPDIR/got.txt")" == "viawget" ]]
}

@test "w_download: fails cleanly when neither curl nor wget is present" {
  local stub="$BATS_TEST_TMPDIR/stub2"
  _link_tools "$stub" bash sed grep cut awk cat mktemp rm mv cp mkdir dirname basename chmod
  run bash -c "
    PATH='$stub'
    source '$LIB'
    w_download 'https://example.com/x' '$BATS_TEST_TMPDIR/x' 2>&1
  "
  (( status == 1 ))
  [[ "$output" =~ "No fetch command found" ]]
}

@test "w_prompt: prints the reply on stdout and the prompt on stderr" {
  run bash -c "printf 'Ada Lovelace\n' | { source '$LIB'; w_prompt 'Enter your Git name' 2>/dev/null; }"
  (( status == 0 ))
  [[ "$output" == "Ada Lovelace" ]]
}

@test "w_prompt: returns an empty string when the user just presses enter" {
  run bash -c "printf '\n' | { source '$LIB'; w_prompt 'Optional value' 2>/dev/null; }"
  (( status == 0 ))
  [[ -z "$output" ]]
}

@test "w_sudo_make_executable: sets the executable bit" {
  _stub_sudo "$BATS_TEST_TMPDIR/bin"
  printf '#!/usr/bin/env bash\n' > "$BATS_TEST_TMPDIR/s.sh"
  run bash -c "
    PATH='$BATS_TEST_TMPDIR/bin:$PATH'
    source '$LIB'
    w_sudo_make_executable '$BATS_TEST_TMPDIR/s.sh'
  "
  (( status == 0 ))
  [[ -x "$BATS_TEST_TMPDIR/s.sh" ]]
}

@test "w_sudo_mkdir: creates a directory and its parents" {
  _stub_sudo "$BATS_TEST_TMPDIR/bin"
  run bash -c "
    PATH='$BATS_TEST_TMPDIR/bin:$PATH'
    source '$LIB'
    w_sudo_mkdir '$BATS_TEST_TMPDIR/a/b/c'
  "
  (( status == 0 ))
  [[ -d "$BATS_TEST_TMPDIR/a/b/c" ]]
}

@test "library: no function calls curl or wget directly except w_download" {
  # A raw curl in the library breaks every wget-only host, exactly as it did
  # in the modules. w_download is the only place the choice may be made.
  local hits
  hits=$(grep -nE '(curl|wget) -' "$LIB" | grep -vE 'curl -fsSL -o \$\{dest\}|wget -q -O \$\{dest\}' || true)
  hits=$(printf '%s\n' "$hits" | grep -vE '"\$\{dest\}" "\$\{url\}"' || true)
  [[ -z "$hits" ]] || printf 'raw fetch outside w_download:\n%s\n' "$hits"
  [[ -z "$hits" ]]
}

# apt package helpers
#
# These shell out to dpkg/apt-get/gpg, which are stubbed on PATH so the branch
# logic (skip-if-installed, install-only-the-missing) is exercised without a
# real package manager or root. A stub dpkg reports the fixture install state; a
# capturing apt-get records what it was asked to do.

@test "w_is_apt_installed: true when dpkg reports the package installed" {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\nprintf "ii  %%s  1.0\\n" "$2"\n' > "$bin/dpkg"
  chmod +x "$bin/dpkg"
  run bash -c "PATH='$bin:$PATH'; source '$LIB'; w_is_apt_installed cowsay"
  (( status == 0 ))
}

@test "w_is_apt_installed: false when dpkg has no matching package" {
  local bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$bin"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$bin/dpkg"
  chmod +x "$bin/dpkg"
  run bash -c "PATH='$bin:$PATH'; source '$LIB'; w_is_apt_installed cowsay"
  (( status != 0 ))
}

@test "w_apt_install: installs only the packages that are not already present" {
  local bin="$BATS_TEST_TMPDIR/bin"
  _stub_sudo "$bin"
  printf '#!/usr/bin/env bash\n[[ "$2" == git ]] && { printf "ii  git\\n"; exit 0; }\nexit 1\n' > "$bin/dpkg"
  chmod +x "$bin/dpkg"
  _capturing_stub "$bin" apt-get
  run bash -c "PATH='$bin:$PATH'; source '$LIB'; w_apt_install git cowsay"
  (( status == 0 ))
  [[ "$output" =~ "git already installed" ]]
  [[ "$output" =~ "Installing: cowsay" ]]
  grep -q 'install -y cowsay' "$bin/apt-get.calls"
  ! grep -q ' git' "$bin/apt-get.calls"
}

@test "w_apt_remove: removes an installed package and skips a missing one" {
  local bin="$BATS_TEST_TMPDIR/bin"
  _stub_sudo "$bin"
  printf '#!/usr/bin/env bash\n[[ "$2" == git ]] && { printf "ii  git\\n"; exit 0; }\nexit 1\n' > "$bin/dpkg"
  chmod +x "$bin/dpkg"
  _capturing_stub "$bin" apt-get
  run bash -c "PATH='$bin:$PATH'; source '$LIB'; w_apt_remove git cowsay"
  (( status == 0 ))
  [[ "$output" =~ "Removing: git" ]]
  [[ "$output" =~ "cowsay not installed" ]]
  grep -q 'remove -y git' "$bin/apt-get.calls"
  ! grep -q 'cowsay' "$bin/apt-get.calls"
}

@test "w_apt_add_key: fetches, dearmors and installs a new keyring" {
  # A name unlikely to already exist under /etc/apt/keyrings, so the guard does
  # not short-circuit on the host's real state.
  local bin="$BATS_TEST_TMPDIR/bin"
  _stub_sudo "$bin"
  _capturing_stub "$bin" install
  _capturing_stub "$bin" gpg
  _capturing_stub "$bin" chmod
  run bash -c "
    PATH='$bin:$PATH'
    source '$LIB'
    w_download() { printf 'KEYDATA\n' > \"\$2\"; }   # stand in for the network fetch
    w_apt_add_key war10cktestkey https://example.com/key.asc
  "
  (( status == 0 ))
  [[ "$output" =~ "Adding GPG key: war10cktestkey" ]]
  grep -q -- '--dearmor -o /etc/apt/keyrings/war10cktestkey.gpg' "$bin/gpg.calls"
}

@test "w_apt_add_source: writes the source entry and refreshes apt" {
  local bin="$BATS_TEST_TMPDIR/bin"
  _stub_sudo "$bin"
  _capturing_stub "$bin" apt-get
  # tee is fed the entry on stdin; capture that rather than writing under /etc.
  printf '#!/usr/bin/env bash\ncat > %q\n' "$bin/tee.stdin" > "$bin/tee"
  chmod +x "$bin/tee"
  run bash -c "
    PATH='$bin:$PATH'
    source '$LIB'
    w_apt_add_source war10cktestsrc 'deb https://example.com/repo stable main'
  "
  (( status == 0 ))
  [[ "$output" =~ "Adding apt source: war10cktestsrc" ]]
  grep -q 'deb https://example.com/repo stable main' "$bin/tee.stdin"
  grep -q 'update' "$bin/apt-get.calls"
}

@test "w_apt_remove_source: no-op when the source file is absent" {
  # The removal branch touches /etc, which the test cannot mutate; this pins the
  # guard that keeps an absent source from erroring out.
  run bash -c "source '$LIB'; w_apt_remove_source war10cktestabsent"
  (( status == 0 ))
  [[ -z "$output" ]]
}

# user/group helpers

@test "w_user_add_group: adds the user when not already a member" {
  local bin="$BATS_TEST_TMPDIR/bin"
  _stub_sudo "$bin"
  _capturing_stub "$bin" usermod
  printf '#!/usr/bin/env bash\nprintf "users sudo\\n"\n' > "$bin/id"
  chmod +x "$bin/id"
  run bash -c "PATH='$bin:$PATH'; USER=tester; source '$LIB'; w_user_add_group docker"
  (( status == 0 ))
  [[ "$output" =~ "Adding tester to group: docker" ]]
  grep -q 'aG docker tester' "$bin/usermod.calls"
}

@test "w_user_add_group: skips when the user is already a member" {
  local bin="$BATS_TEST_TMPDIR/bin"
  _stub_sudo "$bin"
  _capturing_stub "$bin" usermod
  printf '#!/usr/bin/env bash\nprintf "users sudo docker\\n"\n' > "$bin/id"
  chmod +x "$bin/id"
  run bash -c "PATH='$bin:$PATH'; USER=tester; source '$LIB'; w_user_add_group docker"
  (( status == 0 ))
  [[ "$output" =~ "already in group" ]]
  [[ ! -f "$bin/usermod.calls" ]]
}

@test "w_user_remove_group: removes the user when a member" {
  local bin="$BATS_TEST_TMPDIR/bin"
  _stub_sudo "$bin"
  _capturing_stub "$bin" gpasswd
  printf '#!/usr/bin/env bash\nprintf "users sudo docker\\n"\n' > "$bin/id"
  chmod +x "$bin/id"
  run bash -c "PATH='$bin:$PATH'; USER=tester; source '$LIB'; w_user_remove_group docker"
  (( status == 0 ))
  [[ "$output" =~ "Removing tester from group: docker" ]]
  grep -q 'd tester docker' "$bin/gpasswd.calls"
}

@test "w_user_remove_group: skips when the user is not a member" {
  local bin="$BATS_TEST_TMPDIR/bin"
  _stub_sudo "$bin"
  _capturing_stub "$bin" gpasswd
  printf '#!/usr/bin/env bash\nprintf "users sudo\\n"\n' > "$bin/id"
  chmod +x "$bin/id"
  run bash -c "PATH='$bin:$PATH'; USER=tester; source '$LIB'; w_user_remove_group docker"
  (( status == 0 ))
  [[ "$output" =~ "not in group" ]]
  [[ ! -f "$bin/gpasswd.calls" ]]
}

# GitHub release helpers

@test "w_github_latest_tag: returns the tag_name with the leading v stripped" {
  run bash -c "
    source '$LIB'
    w_download() { printf '{\n  \"tag_name\": \"v1.2.3\"\n}\n' > \"\$2\"; }
    w_github_latest_tag owner/repo
  "
  (( status == 0 ))
  [[ "$output" == "1.2.3" ]]
}

@test "w_github_latest_tag: fails when the response carries no tag" {
  run bash -c "
    source '$LIB'
    w_download() { printf '{}\n' > \"\$2\"; }
    w_github_latest_tag owner/repo 2>&1
  "
  (( status != 0 ))
  [[ "$output" =~ "Failed to fetch latest release tag" ]]
}

@test "w_github_checksums_verify: verifies a file listed in the remote checksums" {
  printf 'artifact\n' > "$BATS_TEST_TMPDIR/app.tar.gz"
  local h
  h=$(sha256sum "$BATS_TEST_TMPDIR/app.tar.gz" | cut -d' ' -f1)
  printf '%s  app.tar.gz\n' "$h" > "$BATS_TEST_TMPDIR/checksums.txt"
  run bash -c "
    source '$LIB'
    w_github_checksums_verify '$BATS_TEST_TMPDIR/app.tar.gz' 'app.tar.gz' 'file://$BATS_TEST_TMPDIR/checksums.txt'
  "
  (( status == 0 ))
  [[ "$output" =~ "Checksum OK" ]]
}

@test "w_github_checksums_verify: fails when the archive is absent from the checksums" {
  printf 'artifact\n' > "$BATS_TEST_TMPDIR/app.tar.gz"
  printf 'deadbeef  other.tar.gz\n' > "$BATS_TEST_TMPDIR/checksums.txt"
  run bash -c "
    source '$LIB'
    w_github_checksums_verify '$BATS_TEST_TMPDIR/app.tar.gz' 'app.tar.gz' 'file://$BATS_TEST_TMPDIR/checksums.txt' 2>&1
  "
  (( status != 0 ))
  [[ "$output" =~ "No checksum entry found" ]]
}

@test "w_github_checksums_verify: fails when the listed hash does not match" {
  printf 'artifact\n' > "$BATS_TEST_TMPDIR/app.tar.gz"
  printf 'deadbeef  app.tar.gz\n' > "$BATS_TEST_TMPDIR/checksums.txt"
  run bash -c "
    source '$LIB'
    w_github_checksums_verify '$BATS_TEST_TMPDIR/app.tar.gz' 'app.tar.gz' 'file://$BATS_TEST_TMPDIR/checksums.txt' 2>&1
  "
  (( status != 0 ))
  [[ "$output" =~ "Checksum mismatch" ]]
}

# Remote file deployment (uses FETCH_CMD/BASE_URL, exercised here with _bcp)

@test "w_deploy_remote_file: fetches from BASE_URL via FETCH_CMD and deploys" {
  local base="$BATS_TEST_TMPDIR/base"
  mkdir -p "$base/modules/demo/files"
  printf 'remote-content\n' > "$base/modules/demo/files/thing.conf"
  run bash -c "
    source '$REPO_ROOT/src/lib/private.sh'
    source '$LIB'
    BASE_URL='$base'
    FETCH_CMD='_bcp'
    w_deploy_remote_file 'modules/demo/files/thing.conf' '$BATS_TEST_TMPDIR/out/thing.conf'
  "
  (( status == 0 ))
  [[ "$(cat "$BATS_TEST_TMPDIR/out/thing.conf")" == "remote-content" ]]
}

@test "w_deploy_functions: deploys a module's functions file under HOME" {
  local base="$BATS_TEST_TMPDIR/base"
  mkdir -p "$base/modules/demo/files"
  printf 'alias demo=echo\n' > "$base/modules/demo/files/functions.bash"
  run bash -c "
    source '$REPO_ROOT/src/lib/private.sh'
    source '$LIB'
    BASE_URL='$base'
    FETCH_CMD='_bcp'
    HOME='$BATS_TEST_TMPDIR/home'
    w_deploy_functions demo
    cat \"\$HOME/.war10ck/functions.d/demo\"
  "
  (( status == 0 ))
  [[ "$output" =~ "alias demo=echo" ]]
}

@test "w_remove_functions: removes a module's deployed functions file" {
  local home="$BATS_TEST_TMPDIR/home"
  mkdir -p "$home/.war10ck/functions.d"
  printf 'x\n' > "$home/.war10ck/functions.d/demo"
  run bash -c "
    source '$LIB'
    HOME='$home'
    w_remove_functions demo
  "
  (( status == 0 ))
  [[ ! -f "$home/.war10ck/functions.d/demo" ]]
}
