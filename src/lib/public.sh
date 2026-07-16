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
#   w_github_*    GitHub release helpers
#   w_verify_*    checksum/integrity verification

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
  local _tmpkey
  _tmpkey=$(mktemp --suffix=-key.asc)
  w_download "${url}" "${_tmpkey}"
  sudo gpg --dearmor -o "${keyfile}" "${_tmpkey}"
  rm -f "${_tmpkey}"
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

# Remove the GPG key for an apt repository.
# Inverse of w_apt_add_key.
#
# Arguments:
#   $1 - Short name for the key (e.g. "docker")
w_apt_remove_key() {
  local name=$1
  w_sudo_remove_file "/etc/apt/keyrings/${name}.gpg"
}

# Remove an apt source list entry and refresh the package lists.
# Inverse of w_apt_add_source.
#
# Arguments:
#   $1 - Short name for the source (e.g. "docker")
w_apt_remove_source() {
  local name=$1
  local sourcefile="/etc/apt/sources.list.d/${name}.list"
  if [[ -f "${sourcefile}" ]]; then
    w_log_info "Removing apt source: ${name}"
    sudo rm -f "${sourcefile}"
    w_q sudo apt-get update
  else
    w_log_debug "apt source not present, skipping removal: ${sourcefile}"
  fi
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

# Download a file from an arbitrary URL.
#
# Prefers curl and falls back to wget, mirroring how war10ck itself fetches.
# Modules must use this rather than calling curl directly, or they will break
# on a host that only has wget even though war10ck installed successfully.
#
# Arguments:
#   $1 - URL to download
#   $2 - Destination file path
w_download() {
  local url=$1
  local dest=$2
  if command -v curl &> /dev/null; then
    curl -fsSL -o "${dest}" "${url}"
  elif command -v wget &> /dev/null; then
    wget -q -O "${dest}" "${url}"
  else
    w_log_error "No fetch command found (need curl or wget)"
    return 1
  fi
  w_log_debug "Downloaded: ${url} -> ${dest}"
}

# Prompt the user for a value and print the response to stdout.
#
# The prompt is written to stderr so the caller can capture only the answer
# via command substitution.
#
# Arguments:
#   $1 - Prompt message
# Outputs:
#   The line entered by the user
w_prompt() {
  local message=$1
  local reply
  printf '[?] %s: ' "${message}" >&2
  read -r reply
  printf '%s\n' "${reply}"
}

# Create a root-owned directory, including any missing parents.
#
# Arguments:
#   $1 - Path to the directory
w_sudo_mkdir() {
  sudo mkdir -p "$1"
  w_log_debug "Created directory: $1"
}

# Mark a root-owned file as executable.
#
# Arguments:
#   $1 - Path to the file
w_sudo_make_executable() {
  sudo chmod +x "$1"
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

# Symlink helpers

# Create a symbolic link from source to destination, creating parent
# directories if needed. Replaces an existing symlink or file at the
# destination path.
#
# Arguments:
#   $1 - Source path (what the symlink points to)
#   $2 - Destination path (where the symlink is created)
w_symlink() {
  local src=$1
  local dest=$2
  mkdir -p "$(dirname "${dest}")"
  ln -sf "${src}" "${dest}"
  w_log_info "Symlinked: ${src} -> ${dest}"
}

# Remove a symbolic link if it exists.
#
# Arguments:
#   $1 - Path to the symlink to remove
w_remove_symlink() {
  if [[ -L "$1" ]]; then
    rm -f "$1"
    w_log_info "Removed symlink: $1"
  else
    w_log_debug "Not a symlink, skipping removal: $1"
  fi
}

# Root-owned path helpers
#
# Modules that install into /opt or /usr/local/bin write as root, so the
# unprivileged removal helpers above cannot undo them. These variants shell
# out through sudo and are the correct choice for anything outside $HOME.

# Create a symbolic link at a root-owned destination.
#
# Arguments:
#   $1 - Source path (what the symlink points to)
#   $2 - Destination path (where the symlink is created)
w_sudo_symlink() {
  local src=$1
  local dest=$2
  sudo mkdir -p "$(dirname "${dest}")"
  sudo ln -sf "${src}" "${dest}"
  w_log_info "Symlinked: ${src} -> ${dest}"
}

# Remove a root-owned file if it exists.
#
# Arguments:
#   $1 - Path to the file to remove
w_sudo_remove_file() {
  if [[ -f "$1" ]]; then
    sudo rm -f "$1"
    w_log_info "Removed: $1"
  else
    w_log_debug "Not found, skipping removal: $1"
  fi
}

# Remove a root-owned directory if it exists.
#
# Arguments:
#   $1 - Path to the directory to remove
w_sudo_remove_dir() {
  if [[ -d "$1" ]]; then
    sudo rm -rf "$1"
    w_log_info "Removed directory: $1"
  else
    w_log_debug "Not found, skipping removal: $1"
  fi
}

# Remove a root-owned symlink if it exists.
#
# Arguments:
#   $1 - Path to the symlink to remove
w_sudo_remove_symlink() {
  if [[ -L "$1" ]]; then
    sudo rm -f "$1"
    w_log_info "Removed symlink: $1"
  else
    w_log_debug "Not a symlink, skipping removal: $1"
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

# Remove the current user from a group if they are a member.
# Inverse of w_user_add_group.
#
# Arguments:
#   $1 - Group name
w_user_remove_group() {
  local group=$1
  if id -nG "${USER}" | grep -qw "${group}"; then
    w_log_info "Removing ${USER} from group: ${group}"
    sudo gpasswd -d "${USER}" "${group}"
  else
    w_log_info "${USER} not in group '${group}'. Skipping."
  fi
}

# Download and verify helpers

# Fetch the latest release tag from a GitHub repository, with the leading 'v' stripped.
#
# Arguments:
#   $1 - Repository in "owner/repo" format
# Outputs:
#   Tag string (e.g. "0.13.2") on stdout; returns 1 on failure
w_github_latest_tag() {
  local repo=$1
  local tag
  local _tmpjson
  _tmpjson=$(mktemp --suffix=-release.json)
  w_download "https://api.github.com/repos/${repo}/releases/latest" "${_tmpjson}"
  tag=$(grep '"tag_name":' "${_tmpjson}" | sed -E 's/.*"([^"]+)".*/\1/')
  rm -f "${_tmpjson}"
  if [[ -z "${tag}" ]]; then
    w_log_error "Failed to fetch latest release tag for ${repo}"
    return 1
  fi
  printf '%s\n' "${tag#v}"
}

# Verify a file's SHA256 checksum against an expected value.
# Logs the result and returns 1 on mismatch (caller is responsible for cleanup).
#
# Arguments:
#   $1 - Path to the file to verify
#   $2 - Expected SHA256 hex string
w_verify_sha256() {
  local file=$1
  local expected=$2
  local actual
  actual=$(sha256sum "${file}" | cut -d' ' -f1)
  if [[ "${actual}" != "${expected}" ]]; then
    w_log_error "Checksum mismatch for $(basename "${file}")"
    w_log_error "  expected: ${expected}"
    w_log_error "  actual:   ${actual}"
    return 1
  fi
  w_log_info "Checksum OK: $(basename "${file}")"
}

# Download a checksums file, extract the expected SHA256 for a named archive,
# and verify it. Returns 1 on any failure (caller is responsible for cleanup).
#
# Arguments:
#   $1 - Path to the already-downloaded file to verify
#   $2 - Archive filename to look up in the checksums file
#   $3 - URL to fetch the checksums file from
w_github_checksums_verify() {
  local file=$1
  local archive_name=$2
  local checksums_url=$3
  local _tmpchecksums
  _tmpchecksums=$(mktemp --suffix=-checksums.txt)
  w_download "${checksums_url}" "${_tmpchecksums}"
  local expected
  expected=$(grep "${archive_name}" "${_tmpchecksums}" | cut -d' ' -f1)
  rm -f "${_tmpchecksums}"
  if [[ -z "${expected}" ]]; then
    w_log_error "No checksum entry found for ${archive_name}"
    return 1
  fi
  w_verify_sha256 "${file}" "${expected}"
}

# Bash function helpers

# Deploy a module's bash functions file to ~/.war10ck/functions.d/<module>.
# Source file must be at modules/<module>/files/functions.bash in the repo.
#
# Arguments:
#   $1 - Module name (e.g. "tmux", "uv")
w_deploy_functions() {
  local module=$1
  w_deploy_remote_file "modules/${module}/files/functions.bash" \
    "$HOME/.war10ck/functions.d/${module}"
}

# Remove a module's bash functions from ~/.war10ck/functions.d/<module>.
#
# Arguments:
#   $1 - Module name
w_remove_functions() {
  local module=$1
  w_remove_file "$HOME/.war10ck/functions.d/${module}"
}

# Delete every line matching a regular expression from a file.
#
# Third-party installers (nvm, for example) append their own lines to shell
# rc files rather than confining them to a war10ck-managed block, so undoing
# them means matching those lines directly.
#
# Arguments:
#   $1 - Path to the file to edit
#   $2 - POSIX extended regular expression matching the lines to delete
w_remove_lines() {
  local file=$1
  local pattern=$2
  if [[ ! -f "${file}" ]]; then
    w_log_debug "Not found, skipping line removal: ${file}"
    return 0
  fi
  if grep -Eq "${pattern}" "${file}"; then
    sed -i -E "/${pattern}/d" "${file}"
    w_log_info "Removed matching lines from: ${file}"
  else
    w_log_debug "No matching lines in: ${file}"
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
export -f w_apt_remove_key
export -f w_apt_remove_source
export -f w_deploy_file
export -f w_deploy_remote_file
export -f w_deploy_dir
export -f w_make_executable
export -f w_download
export -f w_prompt
export -f w_sudo_mkdir
export -f w_sudo_make_executable
export -f w_remove_file
export -f w_remove_dir
export -f w_symlink
export -f w_remove_symlink
export -f w_sudo_symlink
export -f w_sudo_remove_file
export -f w_sudo_remove_dir
export -f w_sudo_remove_symlink
export -f w_user_add_group
export -f w_user_remove_group
export -f w_deploy_functions
export -f w_remove_functions
export -f w_remove_lines
export -f w_github_latest_tag
export -f w_verify_sha256
export -f w_github_checksums_verify
