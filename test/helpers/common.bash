# shellcheck shell=bash
#
# Shared bats helpers for the war10ck suite. Load from a test file with:
#   load helpers/common

# Absolute path to the repository root, derived from the test file's location.
#
# Outputs:
#   The repository root path on stdout
_repo_root() {
  cd "$BATS_TEST_DIRNAME/.." && pwd
}

# Install a passthrough `sudo` into a directory so root-owned code paths can run
# unprivileged. The helpers' own logic (existence checks, logging, guards) is
# what is under test, not sudo itself.
#
# Arguments:
#   $1 - directory to place the stub in (created if missing)
_stub_sudo() {
  local dir=$1
  mkdir -p "$dir"
  printf '#!/usr/bin/env bash\nexec "$@"\n' > "$dir/sudo"
  chmod +x "$dir/sudo"
}

# Symlink the named host tools into a directory. Used to build a controlled
# PATH that deliberately omits a tool (curl/wget) while keeping the coreutils
# war10ck needs. Tools missing on the host are skipped silently.
#
# Arguments:
#   $1  - directory to populate (created if missing)
#   $@  - tool names to link
_link_tools() {
  local dir=$1; shift
  mkdir -p "$dir"
  local t p
  for t in "$@"; do
    p=$(command -v "$t") && ln -sf "$p" "$dir/$t"
  done
}

# The coreutils a bundled war10ck invocation relies on, minus curl/wget.
_NONET_TOOLS=(bash sed grep cut awk cat mktemp sha256sum rm mv cp mkdir dirname
              basename chmod find sort xargs id tr head)

# Build a PATH directory with the coreutils war10ck needs but neither curl nor
# wget, so the missing-fetch-tool branch can be exercised.
#
# Arguments:
#   $1 - directory to populate
_make_nonet_path() {
  _link_tools "$1" "${_NONET_TOOLS[@]}"
}

# Create a stub command that records each invocation's arguments to
# <dir>/<name>.calls (one line per call) and exits 0. Lets a test assert *how* a
# helper shelled out without performing the real (often root-only) side effect.
#
# Arguments:
#   $1 - directory to place the stub in (created if missing)
#   $2 - command name to stub
_capturing_stub() {
  local dir=$1 name=$2
  mkdir -p "$dir"
  { printf '#!/usr/bin/env bash\n'
    printf 'printf "%%s\\n" "$*" >> %q\n' "$dir/$name.calls"
  } > "$dir/$name"
  chmod +x "$dir/$name"
}

# Build a minimal local "dist" tree (a demo module + a few profiles) with a real
# checksums.txt, mirroring what bundle.sh produces. Lets the fetch/verify/execute
# pipeline be driven against local files with checksum verification left on.
#
# The demo lifecycle scripts print a recognisable marker so a test can assert
# which steps actually ran. The profiles cover the member-step syntax:
#   foo -> demo (both steps)   bar -> demo:config   baz -> demo:bogus (invalid)
#
# Arguments:
#   $1 - directory to build the tree in (created if missing)
_build_local_dist() {
  local root=$1
  mkdir -p "$root/modules/demo" "$root/profiles"
  printf '#!/usr/bin/env bash\nprintf "DEMO_INSTALLED\\n"\n'   > "$root/modules/demo/install.sh"
  printf '#!/usr/bin/env bash\nprintf "DEMO_CONFIGURED\\n"\n'  > "$root/modules/demo/config.sh"
  printf '#!/usr/bin/env bash\nprintf "DEMO_UNINSTALLED\\n"\n' > "$root/modules/demo/uninstall.sh"
  printf 'NAME="Foo"\nDESCRIPTION="fixture"\nMODULES=( demo )\n' > "$root/profiles/foo"
  printf 'NAME="Bar"\nMODULES=( demo:config )\n'                 > "$root/profiles/bar"
  printf 'NAME="Baz"\nMODULES=( demo:bogus )\n'                  > "$root/profiles/baz"
  ( cd "$root" && find modules profiles -type f -print0 | sort -z \
      | xargs -0 sha256sum > checksums.txt )
}

# Write a .bashrc fixture containing a pub-era block: the four-line stanza
# war10ck appended before the "# war10ck BEGIN" markers existed. Optional
# surrounding lines let a test assert that a block removal takes the block and
# nothing else.
#
# Arguments:
#   $1 - path to write to
#   $2 - line placed before the block (optional)
#   $3 - line placed after the block (optional)
_write_pub_era_bashrc() {
  local file=$1
  local before=${2:-}
  local after=${3:-}
  {
    if [[ -n "$before" ]]; then printf '%s\n' "$before"; fi
    printf '# CUSTOM ALIASES\n'
    printf 'if [ -f ~/.aliases ]; then\n'
    printf '    . ~/.aliases\n'
    printf 'fi\n'
    if [[ -n "$after" ]]; then printf '%s\n' "$after"; fi
  } > "$file"
}

# Build a directory of git repositories in known states, mirroring the
# ~/repos/<org> layout w_git_repository_properties reports on. The tree lands in
# <root>/org, with the matching bare remotes kept out of the way in <root>/rem.
#
# Repositories created, each tracking a local origin:
#   ahead     two commits origin does not have
#   behind    three commits origin has and it does not
#   stale     up to date, plus two local branches never merged into main
#   detached  a detached HEAD and an untracked file
#   nostream  on a branch that tracks nothing
# A plain directory named notarepo is left beside them, so the repository
# detection has something it must skip.
#
# Git's global and system config are replaced for the caller, so a host that
# signs every commit or names a different default branch cannot change what
# the fixture looks like.
#
# Arguments:
#   $1 - directory to build the tree in (created if missing)
_build_repo_fixture() {
  local root=$1
  mkdir -p "$root/org" "$root/rem" "$root/cfg"

  export GIT_CONFIG_GLOBAL="$root/cfg/gitconfig"
  export GIT_CONFIG_SYSTEM=/dev/null
  git config --global user.email bats@example.com
  git config --global user.name bats
  git config --global commit.gpgsign false
  git config --global init.defaultBranch main

  local name
  for name in ahead behind stale detached nostream; do
    git init -q --bare "$root/rem/$name.git"
    git init -q "$root/org/$name"
    printf 'base\n' > "$root/org/$name/f.txt"
    git -C "$root/org/$name" add f.txt
    git -C "$root/org/$name" commit -qm base
    git -C "$root/org/$name" remote add origin "$root/rem/$name.git"
    git -C "$root/org/$name" push -q -u origin main
    git -C "$root/org/$name" remote set-head origin -a > /dev/null 2>&1
  done

  local i
  for i in 1 2; do
    printf 'a%s\n' "$i" >> "$root/org/ahead/f.txt"
    git -C "$root/org/ahead" commit -qam "ahead$i"
  done

  # Commits reach the behind repo's origin through a second clone, which is the
  # only way to put them upstream without also putting them in the repo itself.
  git clone -q "$root/rem/behind.git" "$root/pusher"
  for i in 1 2 3; do
    printf 'b%s\n' "$i" >> "$root/pusher/f.txt"
    git -C "$root/pusher" commit -qam "behind$i"
  done
  git -C "$root/pusher" push -q origin main
  git -C "$root/org/behind" fetch -q origin

  git -C "$root/org/stale" checkout -q -b feature/one
  printf 'one\n' >> "$root/org/stale/f.txt"
  git -C "$root/org/stale" commit -qam feature-one
  git -C "$root/org/stale" checkout -q -b feature/two main
  printf 'two\n' >> "$root/org/stale/f.txt"
  git -C "$root/org/stale" commit -qam feature-two
  git -C "$root/org/stale" checkout -q main

  printf 'scratch\n' > "$root/org/detached/untracked.txt"
  git -C "$root/org/detached" checkout -q --detach HEAD

  git -C "$root/org/nostream" checkout -q -b orphan-work

  mkdir -p "$root/org/notarepo"
}
