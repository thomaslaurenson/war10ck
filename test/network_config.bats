bats_require_minimum_version 1.7.0

load helpers/common

# Exercise the stanza rewrite in the network module's config script.
#
# Only strip_managed_stanzas is driven here. It is the one step in the module
# that destroys information, and a mistake in its awk silently deletes a host's
# network configuration rather than failing loudly.
#
# Environment:
#   REPO_ROOT - absolute path to the repository root, derived from BATS_TEST_DIRNAME
#   CONFIG    - path to the config script under test
#   FIXTURES  - directory holding the interfaces fixtures
#   BIN       - PATH directory holding the passthrough sudo stub
#   DRIVER    - script that loads the config script without running main
#   TARGET    - the working copy of a fixture that the stripper rewrites
setup() {
  REPO_ROOT="$(_repo_root)"
  CONFIG="$REPO_ROOT/src/modules/network/config.sh"
  FIXTURES="$REPO_ROOT/test/fixtures/interfaces"
  BIN="$BATS_TEST_TMPDIR/bin"
  DRIVER="$BATS_TEST_TMPDIR/driver.bash"
  TARGET="$BATS_TEST_TMPDIR/interfaces"

  _stub_sudo "$BIN"

  # The config script ends with `main "$@"`, so dropping its last line leaves
  # the function definitions loadable on their own. Running main instead would
  # deploy files and restart services on the machine running the tests.
  cat > "$DRIVER" <<'DRIVER'
w_log_info() { :; }
w_sudo_mkdir() { :; }
w_deploy_functions() { :; }
w_q() { :; }
eval "$(sed '$d' "$1")"
strip_managed_stanzas
DRIVER
}

# Run the stripper against a copy of a fixture, leaving the result in TARGET.
#
# Arguments:
#   $1 - fixture name under test/fixtures/interfaces
_strip() {
  cp "$FIXTURES/$1" "$TARGET"
  _restrip
}

# Run the stripper again over whatever TARGET currently holds.
_restrip() {
  run env "PATH=$BIN:$PATH" "WAR10CK_INTERFACES=$TARGET" bash "$DRIVER" "$CONFIG"
}

@test "strip: reports a rewrite when stanzas were removed" {
  _strip mixed
  (( status == 0 ))
}

@test "strip: keeps the loopback stanza" {
  _strip mixed
  [[ "$(cat "$TARGET")" =~ "auto lo" ]]
  [[ "$(cat "$TARGET")" =~ "iface lo inet loopback" ]]
}

@test "strip: keeps the interfaces.d source line" {
  _strip mixed
  [[ "$(cat "$TARGET")" =~ "source /etc/network/interfaces.d/" ]]
}

@test "strip: removes the wired stanza that blocks boot on a cableless port" {
  _strip mixed
  [[ ! "$(cat "$TARGET")" =~ enp0s31f6 ]]
}

@test "strip: removes an indented continuation with its stanza" {
  _strip mixed
  [[ ! "$(cat "$TARGET")" =~ "metric 10" ]]
}

@test "strip: removes the wireless stanza and its wpa-conf" {
  _strip mixed
  [[ ! "$(cat "$TARGET")" =~ wlp0s20f3 ]]
  [[ ! "$(cat "$TARGET")" =~ wpa-conf ]]
}

@test "strip: takes a comment heading away with the stanza it introduces" {
  _strip mixed
  [[ ! "$(cat "$TARGET")" =~ "# Ethernet" ]]
  [[ ! "$(cat "$TARGET")" =~ "# Wireless" ]]
  [[ "$(cat "$TARGET")" =~ "# Loopback" ]]
}

@test "strip: keeps a comment that heads no stanza" {
  _strip mixed
  [[ "$(cat "$TARGET")" =~ "This file describes the network interfaces" ]]
}

@test "strip: reports no change when only loopback remains" {
  _strip loopback_only
  (( status == 1 ))
}

@test "strip: leaves an already-stripped file byte-identical" {
  _strip loopback_only
  run diff "$FIXTURES/loopback_only" "$TARGET"
  (( status == 0 ))
}

@test "strip: is idempotent across a second run" {
  _strip mixed
  local first
  first=$(cat "$TARGET")
  _restrip
  (( status == 1 ))
  [[ "$(cat "$TARGET")" == "$first" ]]
}
