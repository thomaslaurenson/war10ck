#!/usr/bin/env bash

set -euo pipefail
[[ "${WAR10CK_DEBUG:-0}" == "1" ]] && set -x

# Temp paths are registered here and removed by the EXIT trap, so a failed
# download or a checksum mismatch cannot leave a half-fetched archive behind.
# The module runner executes this file with `bash install.sh`, so the trap is
# scoped to this script and fires when the module finishes.
_tmppaths=()
_cleanup() {
  [[ ${#_tmppaths[@]} -gt 0 ]] && rm -rf "${_tmppaths[@]}"
  return 0
}
trap _cleanup EXIT

# Update GO_VERSION and GO_SHA256 together when bumping.
# SHA256 values: https://go.dev/dl/?mode=json
readonly GO_VERSION="1.27.0"
readonly GO_SHA256="675c26c449cbb18fc24b74650de1eabbae6e16f64326fd85a283fb3b58280685"
readonly GO_ARCHIVE="go${GO_VERSION}.linux-amd64.tar.gz"

_tmpfile=$(mktemp --suffix=-"${GO_ARCHIVE}")
_tmppaths+=("${_tmpfile}")
w_download "https://go.dev/dl/${GO_ARCHIVE}" "${_tmpfile}"

if ! w_verify_sha256 "${_tmpfile}" "${GO_SHA256}"; then
  exit 1
fi

# Removing the tree first keeps the toolchain a clean replacement: the archive
# unpacks into /usr/local/go, so files dropped by an older release would
# otherwise survive the upgrade.
w_sudo_remove_dir /usr/local/go
w_q sudo tar -C /usr/local -xzf "${_tmpfile}"

w_sudo_symlink /usr/local/go/bin/go /usr/local/bin/go
w_sudo_symlink /usr/local/go/bin/gofmt /usr/local/bin/gofmt

# Update GORELEASER_VERSION and GORELEASER_SHA256 together when bumping.
# SHA256 values: https://github.com/goreleaser/goreleaser/releases
readonly GORELEASER_VERSION="2.17.1"
readonly GORELEASER_SHA256="a99bbc7ae0d8d897b07c4c497a9b62f222558804715ef219d1af05a7e417bc80"
readonly GORELEASER_ARCHIVE="goreleaser_Linux_x86_64.tar.gz"

_tmpfile=$(mktemp --suffix=-"${GORELEASER_ARCHIVE}")
_tmppaths+=("${_tmpfile}")
w_download "https://github.com/goreleaser/goreleaser/releases/download/v${GORELEASER_VERSION}/${GORELEASER_ARCHIVE}" \
  "${_tmpfile}"

if ! w_verify_sha256 "${_tmpfile}" "${GORELEASER_SHA256}"; then
  exit 1
fi

_tmpdir=$(mktemp -d --suffix=-goreleaser)
_tmppaths+=("${_tmpdir}")
w_q tar -C "${_tmpdir}" -xzf "${_tmpfile}" goreleaser
sudo install -m 0755 "${_tmpdir}/goreleaser" /usr/local/bin/goreleaser

# govulncheck ships no prebuilt binaries, so it is built from source with the
# toolchain installed above. There is no SHA256 to pin: the version pin plus
# the Go checksum database (sum.golang.org, consulted by default) is what
# guarantees the source is the same code every time.
# Versions: https://proxy.golang.org/golang.org/x/vuln/@v/list
readonly GOVULNCHECK_VERSION="1.7.0"

# GOBIN puts the freshly built binary somewhere this script owns, so it can be
# installed root-owned rather than left in $GOPATH/bin. GOPATH is not exported
# during install (the config step only writes it to bashrc.d), so go falls back
# to its ~/go default for the module cache, which is where it would land anyway.
_tmpdir=$(mktemp -d --suffix=-govulncheck)
_tmppaths+=("${_tmpdir}")
w_q env GOBIN="${_tmpdir}" /usr/local/go/bin/go install \
  "golang.org/x/vuln/cmd/govulncheck@v${GOVULNCHECK_VERSION}"
sudo install -m 0755 "${_tmpdir}/govulncheck" /usr/local/bin/govulncheck

w_log_info "golang module installed."
