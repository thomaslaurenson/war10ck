#!/usr/bin/env bash
set -euo pipefail

die() { printf '%s: %s\n' "${0##*/}" "$*" >&2; exit 1; }

SRC="src"
DIST="dist"
BUILD_MODE="${BUILD_MODE:-release}"

_cleanup() {
  if [[ -d "${DIST}" ]]; then
    printf '[!] Bundle failed - cleaning up %s/\n' "${DIST}" >&2
    rm -rf "${DIST}"
  fi
}
trap _cleanup ERR

# Strip shellcheck directive lines from a fragment before concatenation.
#
# Arguments:
#   $1 - Path to the source fragment
_strip_shellcheck() { grep -v '^# shellcheck' "$1"; }

# Concatenate the library fragments and entrypoint into a single executable,
# copy the module and profile trees, then generate and embed the manifest.
main() {
  [[ -d "${SRC}/lib" ]] || die "run from the repository root (no ${SRC}/lib directory found)"
  printf '[*] Bundling war10ck...\n'
  mkdir -p "${DIST}"

  # The heredoc-style printfs below emit literal shell code into the generated
  # binary, so ${BASH_SOURCE[0]} and friends must NOT expand here. That is the
  # whole point of the single quotes.
  # shellcheck disable=SC2016
  {
    printf '#!/usr/bin/env bash\n\n'
    printf '# war10ck is executed as a program, but is also sourced into interactive\n'
    printf '# shells by rundmc to register bash completion. The hardening options must\n'
    printf '# apply only when executed: leaking "set -u" into a user shell makes every\n'
    printf '# reference to an unset variable an error, which breaks ordinary use.\n'
    printf 'if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then\n  set -euo pipefail\n'
    printf 'elif [[ -n "${_WAR10CK_LOADED:-}" ]]; then\n'
    printf '  # Already sourced into this shell. Re-sourcing (a bare "source ~/.bashrc",\n'
    printf '  # which is a common thing to do) would re-run the readonly declarations\n'
    printf '  # below and print an error for every one of them.\n'
    printf '  return 0\n'
    printf 'fi\n'
    printf '_WAR10CK_LOADED=1\n\n'
    _strip_shellcheck "${SRC}/lib/version.sh"
    printf '\n'
    _strip_shellcheck "${SRC}/lib/constants.sh"
    printf '\n'
    _strip_shellcheck "${SRC}/lib/private.sh"
    printf '\n'
    _strip_shellcheck "${SRC}/lib/public.sh"
    printf '\n'
    _strip_shellcheck "${SRC}/lib/update.sh"
    printf '\n'
    _strip_shellcheck "${SRC}/lib/modules.sh"
    printf '\n'
    _strip_shellcheck "${SRC}/lib/completion.sh"
    printf '\n'
    _strip_shellcheck "${SRC}/main.sh"
  } > "${DIST}/war10ck"
  chmod +x "${DIST}/war10ck"
  printf '[*] Bundled: %s/war10ck\n' "${DIST}"

  rm -rf "${DIST}/modules"
  cp -r "${SRC}/modules" "${DIST}/modules"
  printf '[*] Copied: %s/modules/\n' "${DIST}"

  rm -rf "${DIST}/profiles"
  cp -r "${SRC}/profiles" "${DIST}/profiles"
  printf '[*] Copied: %s/profiles/\n' "${DIST}"

  cp "install.sh" "${DIST}/install.sh"
  printf '[*] Copied: %s/install.sh\n' "${DIST}"

  sed '1{/^#/d}' README.md > "${DIST}/README.md"
  printf '[*] Copied: %s/README.md\n' "${DIST}"

  # Pages publishes only the artifact, so a CNAME left at the repository root is
  # never served. Without it the custom domain relies solely on the repository
  # setting, and that domain is the one documented install path.
  if [[ -f "CNAME" ]]; then
    cp "CNAME" "${DIST}/CNAME"
    printf '[*] Copied: %s/CNAME\n' "${DIST}"
  fi

  printf '[*] Generating checksums.txt...\n'
  (
    cd "${DIST}"
    # Null-delimited so paths with spaces are handled, sorted for a stable
    # manifest. sha256sum reads the file list from stdin via -.
    find modules profiles -type f -print0 | sort -z \
      | xargs -0 sha256sum > checksums.txt
    sha256sum install.sh >> checksums.txt
  )
  local manifest_lines
  manifest_lines=$(wc -l < "${DIST}/checksums.txt")
  if (( manifest_lines < 2 )); then
    die "checksums.txt has ${manifest_lines} entries; expected the module and profile trees"
  fi
  printf '[*] Generated: %s/checksums.txt (%s entries, without war10ck)\n' \
    "${DIST}" "${manifest_lines}"

  local checksums_sha256
  checksums_sha256=$(sha256sum "${DIST}/checksums.txt" | cut -d' ' -f1)
  sed -i "s/^readonly CHECKSUMS_SHA256=.*/readonly CHECKSUMS_SHA256=\"${checksums_sha256}\"/" \
    "${DIST}/war10ck"
  printf '[*] Embedded CHECKSUMS_SHA256=%s\n' "${checksums_sha256}"

  if [[ "${BUILD_MODE}" == "release" ]]; then
    sed -i 's/^readonly WAR10CK_BUILD=.*/readonly WAR10CK_BUILD="release"/' "${DIST}/war10ck"
    printf '[*] Embedded WAR10CK_BUILD=release\n'
  else
    printf '[*] Skipped WAR10CK_BUILD override (dev mode)\n'
  fi

  # Append the war10ck binary hash last: the checksum embedding above rewrites
  # the binary, so its hash is only stable once those edits are complete.
  (
    cd "${DIST}"
    sha256sum war10ck >> checksums.txt
  )
  printf '[*] Added war10ck hash to checksums.txt\n'

  printf '[*] Bundle complete.\n'
}

main "$@"
