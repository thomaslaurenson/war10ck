bats_require_minimum_version 1.7.0

load helpers/common

# Configure the environment before each test.
#
# Environment:
#   REPO_ROOT - absolute path to the repository root, derived from BATS_TEST_DIRNAME
#   FUNCTIONS - path to the sourced functions file under test
#   BIN       - PATH directory holding the nmcli mock
#   CALLS     - file the mock records its arguments in
setup() {
  REPO_ROOT="$(_repo_root)"
  FUNCTIONS="$REPO_ROOT/src/modules/network/files/functions.bash"
  BIN="$BATS_TEST_TMPDIR/bin"
  CALLS="$BATS_TEST_TMPDIR/nmcli.calls"
  mkdir -p "$BIN"
  ln -sf "$REPO_ROOT/test/helpers/mock_nmcli" "$BIN/nmcli"
}

# Run w_wifi with the nmcli mock ahead of the real one on PATH.
#
# Arguments:
#   $@ - arguments passed straight to w_wifi
_wifi() {
  run env "PATH=$BIN:$PATH" "MOCK_NMCLI_CALLS=$CALLS" "MOCK_NMCLI_OUTPUT=${OUT:-}" \
    bash -c "source '$FUNCTIONS'; w_wifi $*"
}

@test "help: lists every command and exits 0" {
  _wifi --help
  (( status == 0 ))
  [[ "$output" =~ "w_wifi join" ]]
  [[ "$output" =~ "forget SSID" ]]
}

@test "help: reaches the caller without nmcli installed" {
  local empty="$BATS_TEST_TMPDIR/empty"
  _link_tools "$empty" bash
  run env "PATH=$empty" bash -c "source '$FUNCTIONS'; w_wifi --help"
  (( status == 0 ))
  [[ "$output" =~ "Usage: w_wifi" ]]
}

@test "status: reports a missing nmcli rather than failing silently" {
  local empty="$BATS_TEST_TMPDIR/empty"
  _link_tools "$empty" bash
  run env "PATH=$empty" bash -c "source '$FUNCTIONS'; w_wifi status 2>&1"
  (( status == 1 ))
  [[ "$output" =~ "nmcli not found" ]]
}

@test "status: is the command chosen when none is given" {
  OUT='TYPE\tSTATE\tDEVICE\tCONNECTION' _wifi
  (( status == 0 ))
  [[ "$(cat "$CALLS")" == "-f TYPE,STATE,DEVICE,CONNECTION device status" ]]
}

@test "status: keeps the header and drops non-wireless devices" {
  OUT='TYPE      STATE      DEVICE   CONNECTION\nwifi      connected  wlp0s1   Cafe Wifi\nethernet  unmanaged  enp0s3   --\nwifi-p2p  disconnec  p2p-wlp  --'
  _wifi status
  (( status == 0 ))
  [[ "$output" =~ "TYPE" ]]
  [[ "$output" =~ "wlp0s1" ]]
  [[ ! "$output" =~ "enp0s3" ]]
  [[ ! "$output" =~ "p2p-wlp" ]]
}

@test "list: forces a rescan so the results are not a stale cache" {
  _wifi list
  (( status == 0 ))
  [[ "$(cat "$CALLS")" == "device wifi list --rescan yes" ]]
}

@test "saved: keeps a connection whose name contains spaces" {
  OUT='TYPE      AUTOCONNECT  NAME\nwifi      yes          Coffee Shop Guest\nbridge    no           docker0'
  _wifi saved
  (( status == 0 ))
  [[ "$output" =~ "Coffee Shop Guest" ]]
  [[ ! "$output" =~ "docker0" ]]
}

@test "join: asks for the passphrase instead of passing it as an argument" {
  _wifi join '"Coffee Shop"'
  (( status == 0 ))
  [[ "$(cat "$CALLS")" == "--ask device wifi connect Coffee Shop hidden no" ]]
  [[ ! "$(cat "$CALLS")" =~ password ]]
}

@test "join: marks the network hidden when asked" {
  _wifi join HomeNet --hidden
  (( status == 0 ))
  [[ "$(cat "$CALLS")" == "--ask device wifi connect HomeNet hidden yes" ]]
}

@test "join: rejects a missing SSID" {
  _wifi join 2>/dev/null
  (( status == 1 ))
  [[ ! -e "$CALLS" ]]
}

@test "join: rejects an unknown option" {
  run env "PATH=$BIN:$PATH" "MOCK_NMCLI_CALLS=$CALLS" \
    bash -c "source '$FUNCTIONS'; w_wifi join HomeNet --bogus 2>&1"
  (( status == 1 ))
  [[ "$output" =~ "unknown option: --bogus" ]]
  [[ ! -e "$CALLS" ]]
}

@test "forget: deletes the saved connection by name" {
  _wifi forget HomeNet
  (( status == 0 ))
  [[ "$(cat "$CALLS")" == "connection delete id HomeNet" ]]
}

@test "forget: rejects a missing SSID" {
  run env "PATH=$BIN:$PATH" "MOCK_NMCLI_CALLS=$CALLS" \
    bash -c "source '$FUNCTIONS'; w_wifi forget 2>&1"
  (( status == 1 ))
  [[ "$output" =~ "forget needs an SSID" ]]
  [[ ! -e "$CALLS" ]]
}

@test "command: rejects an unknown command" {
  run env "PATH=$BIN:$PATH" "MOCK_NMCLI_CALLS=$CALLS" \
    bash -c "source '$FUNCTIONS'; w_wifi bogus 2>&1"
  (( status == 1 ))
  [[ "$output" =~ "unknown command: bogus" ]]
  [[ ! -e "$CALLS" ]]
}
