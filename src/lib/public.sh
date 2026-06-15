# shellcheck shell=bash
#
# public.sh - war10ck public helper API
#
# All w_ functions defined here are exported via 'export -f' at the bottom of
# this file, making them available to every module script without any sourcing.
#
# Naming convention:
#   w_apt_*       apt package management
#   w_deploy_*    deploy files from a module's files/ directory
#   w_remove_*    remove files/directories war10ck deployed
#   w_user_*      user/group management
#   w_is_*        boolean checks (return 0/1)
#   w_log_*       logging helpers

# Logging

# Print an info message to stdout.
#
# Arguments:
#   $@ - Message text
w_log_info() {
  printf '[*] %s\n' "$*"
}

# Print an error message to stderr.
#
# Arguments:
#   $@ - Message text
w_log_error() {
  printf '[!] %s\n' "$*" >&2
}

# Print a debug message to stdout. Only visible when WAR10CK_DEBUG=1.
#
# Arguments:
#   $@ - Message text
# Environment:
#   WAR10CK_DEBUG - when 1, print the message; otherwise no-op
w_log_debug() {
  [[ "${WAR10CK_DEBUG:-0}" == "1" ]] && printf '[d] %s\n' "$*"
  return 0
}

# Guards

# Run a command silently in normal mode; stream full output in debug mode.
#
# Arguments:
#   $@ - Command and arguments to run
# Environment:
#   WAR10CK_DEBUG - when 1, stream output; otherwise suppress
w_q() {
  if [[ "${WAR10CK_DEBUG:-0}" == "1" ]]; then
    "$@"
  else
    "$@" >/dev/null 2>&1
  fi
}

# Return 0 if the given command exists on PATH, 1 otherwise.
#
# Arguments:
#   $1 - Command name to check
# Returns:
#   0 if found, 1 if not
w_is_installed() {
  command -v "$1" &>/dev/null
}

# Return 0 if the given apt package is installed, 1 otherwise.
#
# Arguments:
#   $1 - Package name to check
# Returns:
#   0 if installed, 1 if not
w_is_apt_installed() {
  dpkg -l "$1" 2>/dev/null | grep -q '^ii'
}

# apt helpers

# Install one or more apt packages, skipping any that are already installed.
#
# Arguments:
#   $@ - One or more package names
# Environment:
#   WAR10CK_DEBUG - when 1, streams apt output to stdout
w_apt_install() {
  local to_install=()
  for pkg in "$@"; do
    if w_is_apt_installed "${pkg}"; then
      w_log_info "${pkg} already installed. Skipping."
    else
      to_install+=("${pkg}")
    fi
  done
  if (( ${#to_install[@]} > 0 )); then
    w_log_info "Installing: ${to_install[*]}"
    w_q sudo apt-get update
    w_q sudo apt-get install -y "${to_install[@]}"
  fi
}

# Remove one or more apt packages, skipping any that are not installed.
#
# Arguments:
#   $@ - One or more package names
w_apt_remove() {
  for pkg in "$@"; do
    if w_is_apt_installed "${pkg}"; then
      w_log_info "Removing: ${pkg}"
      w_q sudo apt-get remove -y "${pkg}"
    else
      w_log_info "${pkg} not installed. Skipping."
    fi
  done
}

# Add a GPG key for an apt repository.
# Fetches the key from a URL and writes it to /etc/apt/keyrings/<name>.gpg
# Skips if the key file already exists.
#
# Arguments:
#   $1 - Short name for the key (used as filename, e.g. "docker")
#   $2 - URL to fetch the key from
w_apt_add_key() {
  local name=$1
  local url=$2
  local keyfile="/etc/apt/keyrings/${name}.gpg"
  if [[ -f "${keyfile}" ]]; then
    w_log_info "GPG key already present: ${keyfile}. Skipping."
    return 0
  fi
  w_log_info "Adding GPG key: ${name}"
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "${url}" | sudo gpg --dearmor -o "${keyfile}"
  sudo chmod a+r "${keyfile}"
}

# Add an apt source list entry.
# Skips if the source file already exists.
#
# Arguments:
#   $1 - Short name for the source (used as filename, e.g. "docker")
#   $2 - Full source list entry string
w_apt_add_source() {
  local name=$1
  local entry=$2
  local sourcefile="/etc/apt/sources.list.d/${name}.list"
  if [[ -f "${sourcefile}" ]]; then
    w_log_info "apt source already present: ${sourcefile}. Skipping."
    return 0
  fi
  w_log_info "Adding apt source: ${name}"
  printf '%s\n' "${entry}" | sudo tee "${sourcefile}" > /dev/null
  w_q sudo apt-get update
}

# File deployment

# Deploy a single file from a local source path, creating the destination
# directory if needed.
#
# Arguments:
#   $1 - Source file path (local)
#   $2 - Destination file path
w_deploy_file() {
  local src=$1
  local dest=$2
  mkdir -p "$(dirname "${dest}")"
  cp "${src}" "${dest}"
  w_log_debug "Deployed: ${src} -> ${dest}"
}

# Fetch a file from BASE_URL and deploy it to a local destination.
# Uses the same fetch command (curl/wget/cp) that war10ck itself uses.
#
# Arguments:
#   $1 - Remote path relative to BASE_URL (e.g. "modules/polybar/files/config.ini")
#   $2 - Destination file path
# Environment:
#   BASE_URL  - base URL or local path for fetching files
#   FETCH_CMD - fetch command to use (curl, wget, or _bcp)
w_deploy_remote_file() {
  local remote_path=$1
  local dest=$2
  mkdir -p "$(dirname "${dest}")"
  local _tmpfile
  _tmpfile=$(mktemp --suffix="-$(basename "${dest}")")
  $FETCH_CMD "${_tmpfile}" "${BASE_URL}/${remote_path}"
  mv "${_tmpfile}" "${dest}"
  w_log_debug "Deployed remote: ${BASE_URL}/${remote_path} -> ${dest}"
}

# Deploy a directory recursively, creating the destination if needed.
#
# Arguments:
#   $1 - Source directory path
#   $2 - Destination directory path
w_deploy_dir() {
  local src=$1
  local dest=$2
  mkdir -p "${dest}"
  cp -r "${src}/." "${dest}/"
  w_log_debug "Deployed dir: ${src} -> ${dest}"
}

# Mark a deployed file as executable.
#
# Arguments:
#   $1 - Path to the file
w_make_executable() {
  chmod +x "$1"
  w_log_debug "Made executable: $1"
}

# File removal

# Remove a single file if it exists.
#
# Arguments:
#   $1 - Path to the file to remove
w_remove_file() {
  if [[ -f "$1" ]]; then
    rm -f "$1"
    w_log_info "Removed: $1"
  else
    w_log_debug "Not found, skipping removal: $1"
  fi
}

# Remove a directory if it exists.
#
# Arguments:
#   $1 - Path to the directory to remove
w_remove_dir() {
  if [[ -d "$1" ]]; then
    rm -rf "$1"
    w_log_info "Removed directory: $1"
  else
    w_log_debug "Not found, skipping removal: $1"
  fi
}

# User helpers

# Add the current user to a group if not already a member.
#
# Arguments:
#   $1 - Group name
w_user_add_group() {
  local group=$1
  if id -nG "${USER}" | grep -qw "${group}"; then
    w_log_info "${USER} already in group '${group}'. Skipping."
  else
    w_log_info "Adding ${USER} to group: ${group}"
    sudo usermod -aG "${group}" "${USER}"
  fi
}

# Export all public functions to child processes (module scripts)

export -f w_log_info
export -f w_log_error
export -f w_log_debug
export -f w_q
export -f w_is_installed
export -f w_is_apt_installed
export -f w_apt_install
export -f w_apt_remove
export -f w_apt_add_key
export -f w_apt_add_source
export -f w_deploy_file
export -f w_deploy_remote_file
export -f w_deploy_dir
export -f w_make_executable
export -f w_remove_file
export -f w_remove_dir
export -f w_user_add_group
