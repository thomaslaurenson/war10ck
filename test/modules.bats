bats_require_minimum_version 1.7.0

# Structural invariants that every module must hold. These are what stop a new
# module being added with a half-finished lifecycle, or a script drifting off
# the public API and calling raw commands instead.
#
# Environment:
#   REPO_ROOT - absolute path to the repository root, derived from BATS_TEST_DIRNAME
#   MODULES   - path to the modules tree
setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  MODULES="$REPO_ROOT/src/modules"
  PUBLIC="$REPO_ROOT/src/lib/public.sh"
}

@test "modules: every module ships an install.sh" {
  local missing=()
  local d m
  for d in "$MODULES"/*/; do
    m=$(basename "$d")
    [[ -f "$d/install.sh" ]] || missing+=("$m")
  done
  [[ ${#missing[@]} -eq 0 ]] || printf 'missing install.sh: %s\n' "${missing[*]}"
  (( ${#missing[@]} == 0 ))
}

@test "modules: every module ships an uninstall.sh" {
  local missing=()
  local d m
  for d in "$MODULES"/*/; do
    m=$(basename "$d")
    [[ -f "$d/uninstall.sh" ]] || missing+=("$m")
  done
  [[ ${#missing[@]} -eq 0 ]] || printf 'missing uninstall.sh: %s\n' "${missing[*]}"
  (( ${#missing[@]} == 0 ))
}

@test "modules: every module script is valid bash" {
  local f
  for f in "$MODULES"/*/*.sh; do
    bash -n "$f" || { printf 'syntax error: %s\n' "$f"; return 1; }
  done
}

@test "modules: every w_ call resolves to a function defined in public.sh" {
  local defined used undefined
  defined=$(grep -oE '^w_[a-z0-9_]+\(\)' "$PUBLIC" | tr -d '()' | sort -u)
  used=$(grep -rhoE '\bw_[a-z0-9_]+' "$MODULES" --include='*.sh' | sort -u)
  undefined=$(comm -13 <(printf '%s\n' "$defined") <(printf '%s\n' "$used"))
  [[ -z "$undefined" ]] || printf 'undefined: %s\n' "$undefined"
  [[ -z "$undefined" ]]
}

@test "modules: every public function is exported to module subshells" {
  local defined exported
  defined=$(grep -oE '^w_[a-z0-9_]+\(\)' "$PUBLIC" | tr -d '()' | sort)
  exported=$(grep -oE '^export -f w_[a-z0-9_]+' "$PUBLIC" | awk '{print $3}' | sort)
  [[ "$defined" == "$exported" ]]
}

# Lifecycle scripts (install/config/uninstall) run inside war10ck with the
# public API exported, so they must use it. Scripts under files/ are deployed
# runtime assets that execute outside war10ck and must NOT use the w_ API, so
# they are deliberately excluded from these audits.
#
# Outputs:
#   Newline-separated list of lifecycle script paths
_lifecycle_scripts() {
  ls "$MODULES"/*/install.sh "$MODULES"/*/config.sh "$MODULES"/*/uninstall.sh 2>/dev/null
}

@test "modules: no lifecycle script calls curl or wget directly" {
  local hits
  # Matches curl/wget as an invocation (followed by a flag, or inside a command
  # substitution), not as an apt package name in an install list.
  hits=$(grep -nE '(curl|wget) -|\$\((curl|wget) ' $(_lifecycle_scripts) | grep -vE ':[0-9]+:[[:space:]]*#' || true)
  [[ -z "$hits" ]] || printf 'use w_download instead:
%s
' "$hits"
  [[ -z "$hits" ]]
}

@test "modules: no lifecycle script shells out to sudo directly" {
  local hits
  hits=$(grep -nE 'sudo (rm|ln|chmod|mkdir) ' $(_lifecycle_scripts) | grep -vE ':[0-9]+:[[:space:]]*#' || true)
  [[ -z "$hits" ]] || printf 'use the w_sudo_* helpers instead:
%s
' "$hits"
  [[ -z "$hits" ]]
}

@test "modules: no lifecycle script calls apt-get directly" {
  local hits
  hits=$(grep -nE 'apt(-get)? (install|remove|purge)' $(_lifecycle_scripts) | grep -vE ':[0-9]+:[[:space:]]*#' || true)
  [[ -z "$hits" ]] || printf 'use w_apt_install/w_apt_remove instead:
%s
' "$hits"
  [[ -z "$hits" ]]
}

@test "modules: no lifecycle script manages groups directly" {
  local hits
  hits=$(grep -nE '(usermod|gpasswd)' $(_lifecycle_scripts) | grep -vE ':[0-9]+:[[:space:]]*#' || true)
  [[ -z "$hits" ]] || printf 'use w_user_add_group/w_user_remove_group instead:
%s
' "$hits"
  [[ -z "$hits" ]]
}

@test "modules: no script redefines the public w_q helper" {
  run grep -rnE '^_q\(\)' "$MODULES" --include='*.sh'
  (( status != 0 ))
}

@test "modules: every install.sh sets errexit, nounset and pipefail" {
  local f missing=()
  for f in "$MODULES"/*/install.sh; do
    grep -q 'set -euo pipefail' "$f" || missing+=("$f")
  done
  [[ ${#missing[@]} -eq 0 ]] || printf 'missing set -euo pipefail: %s\n' "${missing[*]}"
  (( ${#missing[@]} == 0 ))
}

@test "modules: every uninstall.sh sets errexit, nounset and pipefail" {
  local f missing=()
  for f in "$MODULES"/*/uninstall.sh; do
    grep -q 'set -euo pipefail' "$f" || missing+=("$f")
  done
  [[ ${#missing[@]} -eq 0 ]] || printf 'missing set -euo pipefail: %s\n' "${missing[*]}"
  (( ${#missing[@]} == 0 ))
}

@test "modules: every uninstall.sh honours WAR10CK_DEBUG tracing" {
  local f missing=()
  for f in "$MODULES"/*/uninstall.sh; do
    grep -q 'WAR10CK_DEBUG' "$f" || missing+=("$f")
  done
  [[ ${#missing[@]} -eq 0 ]] || printf 'missing debug trace: %s\n' "${missing[*]}"
  (( ${#missing[@]} == 0 ))
}

@test "modules: every install.sh honours WAR10CK_DEBUG tracing" {
  local f missing=()
  for f in "$MODULES"/*/install.sh; do
    grep -q 'WAR10CK_DEBUG' "$f" || missing+=("$f")
  done
  [[ ${#missing[@]} -eq 0 ]] || printf 'missing debug trace: %s\n' "${missing[*]}"
  (( ${#missing[@]} == 0 ))
}

# config.sh is optional (only modules that need configuration ship one), so the
# audits below iterate the files that exist rather than requiring one per module.

@test "modules: every config.sh sets errexit, nounset and pipefail" {
  local f missing=()
  for f in "$MODULES"/*/config.sh; do
    [[ -e "$f" ]] || continue
    grep -q 'set -euo pipefail' "$f" || missing+=("$f")
  done
  [[ ${#missing[@]} -eq 0 ]] || printf 'missing set -euo pipefail: %s\n' "${missing[*]}"
  (( ${#missing[@]} == 0 ))
}

@test "modules: every config.sh honours WAR10CK_DEBUG tracing" {
  local f missing=()
  for f in "$MODULES"/*/config.sh; do
    [[ -e "$f" ]] || continue
    grep -q 'WAR10CK_DEBUG' "$f" || missing+=("$f")
  done
  [[ ${#missing[@]} -eq 0 ]] || printf 'missing debug trace: %s\n' "${missing[*]}"
  (( ${#missing[@]} == 0 ))
}
