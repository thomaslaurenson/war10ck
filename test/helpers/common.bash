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
