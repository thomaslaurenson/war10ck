# shellcheck shell=bash

# Registry of gpipe-installed tools. Each file in the directory is named for
# the binary it describes and holds key=value lines:
#
#   repo=owner/name    required, the GitHub repository to install from
#   binary=name        optional, when the binary name differs from the filename
#   mode=user|system   optional, the install.sh flag to use; defaults to system
#
# The registry records no versions. Installed versions are read from the
# binaries themselves and latest versions from GitHub, so nothing here can go
# stale and no installer ever has to write to it.
readonly W_GPIPE_DIR="${HOME}/.war10ck/gpipe.d"

# Read a key from a registry file.
#
# Arguments:
#   $1 - Registry file path
#   $2 - Key name
#   $3 - Default value used when the key is absent or empty (optional)
# Outputs:
#   stdout: the value, or the default
_w_gpipe_get() {
  local file=$1
  local key=$2
  local default=${3:-}
  local value
  value=$(grep -E "^${key}=" "${file}" 2>/dev/null | tail -1 | cut -d'=' -f2-)
  printf '%s\n' "${value:-${default}}"
}

# Print the paths of every registry file, one per line.
#
# Returns:
#   1 when the registry directory is missing or holds no files
_w_gpipe_registry() {
  [[ -d "${W_GPIPE_DIR}" ]] || return 1
  local -a files=()
  local file
  for file in "${W_GPIPE_DIR}"/*; do
    [[ -f "${file}" ]] && files+=("${file}")
  done
  (( ${#files[@]} )) || return 1
  printf '%s\n' "${files[@]}"
}

# Print the message shown when the registry is absent, so the two callers that
# need it stay in agreement about how to fix it.
_w_gpipe_no_registry() {
  w_log_error "No gpipe registry found at ${W_GPIPE_DIR}"
  w_log_error "Run 'war10ck install gpipe' to deploy it."
}

# Print the installed version of a tool.
#
# type -P is used rather than command -v because war10ck defines a gpipe()
# function for its own subcommand, which shadows the gpipe binary inside this
# process. type -P searches PATH only, and invoking the resolved absolute path
# keeps the shadowing from turning a version check into a recursive call.
#
# Tools disagree on version output: moon prints "0.3.0" while cobra's default
# prints "gpipe 1.4.0". The last whitespace-separated field is taken and any
# leading v stripped, which matches what w_github_latest_tag returns.
#
# Arguments:
#   $1 - Binary name
# Outputs:
#   stdout: version, "-" when not on PATH, or "?" when it printed nothing usable
_w_gpipe_installed_version() {
  local binary=$1
  local path version
  path=$(type -P "${binary}" 2>/dev/null)
  if [[ -z "${path}" ]]; then
    printf -- '-\n'
    return 0
  fi
  version=$("${path}" version 2>/dev/null | head -1 | awk '{print $NF}')
  version=${version#v}
  printf '%s\n' "${version:-?}"
}

# Print the latest released version for a repository, or "?" when it cannot be
# determined. w_github_latest_tag already strips the leading v.
#
# Arguments:
#   $1 - Repository in owner/repo format
_w_gpipe_latest_version() {
  local latest
  latest=$(w_github_latest_tag "$1" 2>/dev/null)
  printf '%s\n' "${latest:-?}"
}

# Compare an installed version against the latest and print a status word.
#
# Arguments:
#   $1 - Installed version, "-", or "?"
#   $2 - Latest version or "?"
# Outputs:
#   stdout: one of missing, unknown, ok, outdated
_w_gpipe_compare() {
  local installed=$1
  local latest=$2
  if [[ "${installed}" == "-" ]]; then
    printf 'missing\n'
  elif [[ "${installed}" == "?" || "${latest}" == "?" ]]; then
    printf 'unknown\n'
  elif [[ "${installed}" == "${latest}" ]]; then
    printf 'ok\n'
  else
    printf 'outdated\n'
  fi
}

# Return 0 when a name appears in the remaining arguments.
#
# Arguments:
#   $1 - Name to look for
#   $@ - Names to search
_w_gpipe_wanted() {
  local needle=$1
  shift
  local item
  for item in "$@"; do
    [[ "${item}" == "${needle}" ]] && return 0
  done
  return 1
}

# Print a table of every registered tool with its installed and latest version.
# One GitHub API call per tool, no downloads.
_w_gpipe_status() {
  local -a files=()
  mapfile -t files < <(_w_gpipe_registry)
  if (( ${#files[@]} == 0 )); then
    _w_gpipe_no_registry
    return 1
  fi

  printf '\n%-12s %-12s %-12s %s\n' "TOOL" "INSTALLED" "LATEST" "STATUS"
  printf '%-12s %-12s %-12s %s\n' "----" "---------" "------" "------"

  local file name repo binary installed latest
  for file in "${files[@]}"; do
    name=$(basename "${file}")
    repo=$(_w_gpipe_get "${file}" repo)
    if [[ -z "${repo}" ]]; then
      printf '%-12s %-12s %-12s %s\n' "${name}" "-" "-" "no repo= key"
      continue
    fi
    binary=$(_w_gpipe_get "${file}" binary "${name}")
    installed=$(_w_gpipe_installed_version "${binary}")
    latest=$(_w_gpipe_latest_version "${repo}")
    printf '%-12s %-12s %-12s %s\n' \
      "${name}" "${installed}" "${latest}" "$(_w_gpipe_compare "${installed}" "${latest}")"
  done
  printf '\n'
}

# Install or update a single tool by running its own gpipe-generated installer,
# which already handles platform detection, cosign verification, checksums,
# and PATH.
#
# The installer is downloaded to a file rather than piped into bash. Piping
# would let the installer consume the caller's stdin mid-loop, and running
# from a file is what lets sudo drive it without a second prompt.
#
# Arguments:
#   $1 - Tool name (for messages)
#   $2 - Repository in owner/repo format
#   $3 - Install mode, user or system
# Returns:
#   1 if the download or the installer fails
_w_gpipe_install() {
  local name=$1
  local repo=$2
  local mode=$3
  local url="https://github.com/${repo}/releases/latest/download/install.sh"
  local tmp rc=0

  w_log_info "Updating ${name} from ${repo}..."
  tmp=$(mktemp --suffix="-${name}-install.sh")
  if ! w_download "${url}" "${tmp}"; then
    w_log_error "${name}: failed to download ${url}"
    rm -f "${tmp}"
    return 1
  fi

  if [[ "${mode}" == "user" ]]; then
    bash "${tmp}" --user || rc=1
  else
    # Run the whole installer as root so its unprivileged write to
    # /usr/local/bin never fails, and its interactive sudo menu never opens.
    sudo bash "${tmp}" --system || rc=1
  fi
  rm -f "${tmp}"

  (( rc == 0 )) || w_log_error "${name}: installer failed"
  return "${rc}"
}

# Update registered tools.
#
# With no arguments, every tool that is outdated or missing is installed and
# everything already current is left alone. Naming tools explicitly reinstalls
# them regardless of version, which is the way to force a repair.
#
# Arguments:
#   $@ - Tool names to update (optional)
_w_gpipe_update() {
  local -a requested=("$@")
  local -a files=()
  mapfile -t files < <(_w_gpipe_registry)
  if (( ${#files[@]} == 0 )); then
    _w_gpipe_no_registry
    return 1
  fi

  # Resolve the work before touching sudo or the network, so a run with
  # nothing to do neither prompts for a password nor downloads anything.
  local -a pending=()
  local file name repo binary mode installed latest
  for file in "${files[@]}"; do
    name=$(basename "${file}")
    if (( ${#requested[@]} )); then
      _w_gpipe_wanted "${name}" "${requested[@]}" || continue
    fi

    repo=$(_w_gpipe_get "${file}" repo)
    if [[ -z "${repo}" ]]; then
      w_log_error "${name}: no repo= key, skipping"
      continue
    fi
    binary=$(_w_gpipe_get "${file}" binary "${name}")
    mode=$(_w_gpipe_get "${file}" mode system)

    if (( ${#requested[@]} == 0 )); then
      installed=$(_w_gpipe_installed_version "${binary}")
      latest=$(_w_gpipe_latest_version "${repo}")
      case "$(_w_gpipe_compare "${installed}" "${latest}")" in
        ok)
          w_log_info "${name}: up to date (${installed})"
          continue
          ;;
        unknown)
          w_log_error "${name}: could not determine versions, skipping"
          continue
          ;;
      esac
    fi
    pending+=("${name}|${repo}|${mode}")
  done

  if (( ${#requested[@]} )); then
    for name in "${requested[@]}"; do
      [[ -f "${W_GPIPE_DIR}/${name}" ]] || w_log_error "${name}: not in the registry"
    done
  fi

  if (( ${#pending[@]} == 0 )); then
    w_log_info "Nothing to do."
    return 0
  fi

  # Prime the sudo timestamp once, rather than paying a password prompt per
  # tool as each installer runs.
  local entry
  for entry in "${pending[@]}"; do
    if [[ "${entry##*|}" == "system" ]]; then
      w_log_info "Priming sudo for system installs..."
      sudo -v || { w_log_error "sudo is required for system installs"; return 1; }
      break
    fi
  done

  local rc=0
  for entry in "${pending[@]}"; do
    IFS='|' read -r name repo mode <<< "${entry}"
    _w_gpipe_install "${name}" "${repo}" "${mode}" || rc=1
  done
  return "${rc}"
}

# Manage tools installed by gpipe-generated installers.
#
# Arguments:
#   $1 - Action: status (default) or update
#   $@ - Remaining arguments passed to the action
gpipe() {
  local action=${1:-status}
  shift || true
  case "${action}" in
    status) _w_gpipe_status ;;
    update) _w_gpipe_update "$@" ;;
    *)
      w_log_error "Unknown gpipe action: ${action}"
      w_log_error "Usage: war10ck gpipe [status|update [tool...]]"
      return 1
      ;;
  esac
}
