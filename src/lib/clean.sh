# shellcheck shell=bash

# Catalogue of artefacts left behind by earlier versions of war10ck.
#
# Every entry is something a previous version created and a later version
# stopped managing: a rename, a relocation, or a module that was deleted. The
# catalogue is deliberately a fixed list rather than a rule - guessing which
# files are stale is how a cleaner deletes something it should not.
#
# Nothing here may collide with a path the current version still writes. That
# is easy to get wrong, because several live paths look exactly like dead ones
# (~/.tmux.conf, ~/.war10ck/.aliases and ~/ramdisk are all current), so
# test/clean.bats asserts no catalogued path appears anywhere in src/modules.
#
# System paths are out of scope: clean only touches $HOME, never /usr, /etc or
# apt configuration.
#
# Format: kind|path|superseded by
#   file    - a regular file, removed outright
#   dir     - a directory, removed only when empty
#   mount   - a directory that may hold live mounts, removed only when empty
#             and only when nothing is mounted under it
#
# Files are listed before the directories that contain them, so a directory
# becomes empty in the same pass that clears it.
readonly W_CLEAN_ENTRIES=(
  # The pub era, before the 2025-06 rename to war10ck
  "file|${HOME}/.functions|~/.war10ck/functions.d/"
  "file|${HOME}/.aliases|~/.war10ck/.aliases"
  "file|${HOME}/.tmux/cer|~/.war10ck/tmux/cer"
  "file|${HOME}/.tmux/homelab|dropped"
  "dir|${HOME}/.tmux|~/.war10ck/tmux/"

  # The early ~/.war10ck layout, when sourced files were dot-prefixed
  "file|${HOME}/.war10ck/.functions|~/.war10ck/functions.d/"
  "file|${HOME}/.war10ck/.commands|dropped"
  "file|${HOME}/.war10ck/.gitconfig|~/.gitconfig"
  "file|${HOME}/.war10ck/.tmux.conf|~/.tmux.conf"
  "file|${HOME}/.war10ck/.tmux/tmux.conf|~/.war10ck/tmux/tmux.conf"
  "file|${HOME}/.war10ck/.tmux/cer|~/.war10ck/tmux/cer"
  "file|${HOME}/.war10ck/.tmux/home|~/.war10ck/tmux/home"
  "dir|${HOME}/.war10ck/.tmux|~/.war10ck/tmux/"

  # Module environment fragments, before env.d
  "file|${HOME}/.war10ck/bashrc.d/golang|~/.war10ck/env.d/golang"
  "file|${HOME}/.war10ck/bashrc.d/ghidra|~/.war10ck/env.d/ghidra"

  # i3 config, before it moved out of ~/.config
  "file|${HOME}/.config/i3/scripts/display-setup.sh|~/.war10ck/i3/scripts/"
  "dir|${HOME}/.config/i3/scripts|~/.war10ck/i3/scripts/"
  "file|${HOME}/.config/i3/layouts/docked_ws2.json|dropped"
  "dir|${HOME}/.config/i3/layouts|dropped"

  # The sshfs shell helpers, replaced by the smount tool
  "file|${HOME}/.war10ck/functions.d/sshfs|smount"
  "file|${HOME}/.war10ck/.sshfs_favorites|smount"
  "mount|${HOME}/sshfs|smount"
)

# Blocks appended to ~/.bashrc by the pub era. These predate the
# "# war10ck BEGIN/END" markers, so no version of war10ck has ever been able
# to find them, and they source files that were removed years ago.
#
# Format: start pattern|end pattern|description
readonly W_CLEAN_BASHRC_BLOCKS=(
  "^# CUSTOM FUNCTIONS$|^fi$|sources ~/.functions"
  "^# CUSTOM ALIASES$|^fi$|sources ~/.aliases"
)

# Print a path with $HOME collapsed to ~, so the report stays readable.
_w_clean_display() {
  printf '%s\n' "${1/#${HOME}/\~}"
}

# Return 0 when a directory holds no entries, including dotfiles.
_w_clean_dir_empty() {
  local dir=$1
  [[ -d "${dir}" ]] || return 1
  local -a found=()
  mapfile -t found < <(find "${dir}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)
  (( ${#found[@]} == 0 ))
}

# Return 0 when anything is mounted at or under a path. Used to keep clean
# away from a ~/sshfs that still has live mounts in it.
_w_clean_has_mounts() {
  local path=$1
  grep -qE " ${path}(/[^ ]*)? " /proc/mounts 2>/dev/null
}

# Print the catalogue entries that are actually present, one per line, in
# catalogue order. Entries that are present but not safe to remove are
# reported by _w_clean_report rather than filtered here.
_w_clean_present() {
  local entry kind path
  for entry in "${W_CLEAN_ENTRIES[@]}"; do
    IFS='|' read -r kind path _ <<< "${entry}"
    case "${kind}" in
      file)          [[ -f "${path}" || -L "${path}" ]] && printf '%s\n' "${entry}" ;;
      dir|mount)     [[ -d "${path}" ]] && printf '%s\n' "${entry}" ;;
    esac
  done
  return 0
}

# Print the table of artefacts found. Returns 1 when there is nothing to show,
# so the caller can skip straight to a "nothing to do" message.
_w_clean_report() {
  local -a present=()
  mapfile -t present < <(_w_clean_present)

  local -a blocks=()
  local block start_re end_re description range
  for block in "${W_CLEAN_BASHRC_BLOCKS[@]}"; do
    IFS='|' read -r start_re end_re description <<< "${block}"
    range=$(w_block_range "${HOME}/.bashrc" "${start_re}" "${end_re}")
    [[ -n "${range}" ]] && blocks+=("${range}|${description}")
  done

  (( ${#present[@]} || ${#blocks[@]} )) || return 1

  if (( ${#present[@]} )); then
    printf '\n%-42s %-7s %s\n' "ARTEFACT" "KIND" "SUPERSEDED BY"
    printf '%-42s %-7s %s\n' "--------" "----" "-------------"
    local entry kind path superseded note
    for entry in "${present[@]}"; do
      IFS='|' read -r kind path superseded <<< "${entry}"
      note="${superseded}"
      if [[ "${kind}" == "mount" ]] && _w_clean_has_mounts "${path}"; then
        note="in use - will be skipped"
      elif [[ "${kind}" == "dir" || "${kind}" == "mount" ]] && ! _w_clean_dir_empty "${path}"; then
        note="not empty - will be skipped"
      fi
      printf '%-42s %-7s %s\n' "$(_w_clean_display "${path}")" "${kind}" "${note}"
    done
  fi

  if (( ${#blocks[@]} )); then
    printf '\n%s\n' "Blocks in $(_w_clean_display "${HOME}/.bashrc"):"
    local range_desc lines
    for range_desc in "${blocks[@]}"; do
      IFS='|' read -r range description <<< "${range_desc}"
      printf '\n  lines %s-%s (%s)\n' "${range% *}" "${range#* }" "${description}"
      lines=$(sed -n "${range% *},${range#* }p" "${HOME}/.bashrc")
      printf '%s\n' "${lines}" | sed 's/^/    | /'
    done
  fi
  printf '\n'
}

# Remove the catalogued paths that are present and safe to remove.
_w_clean_apply_paths() {
  local -a present=()
  mapfile -t present < <(_w_clean_present)
  (( ${#present[@]} )) || return 0

  local entry kind path
  for entry in "${present[@]}"; do
    IFS='|' read -r kind path _ <<< "${entry}"
    case "${kind}" in
      file)
        w_remove_file "${path}"
        ;;
      mount)
        if _w_clean_has_mounts "${path}"; then
          w_log_error "$(_w_clean_display "${path}"): something is mounted here, skipping"
          continue
        fi
        if _w_clean_dir_empty "${path}"; then
          w_remove_dir "${path}"
        else
          w_log_info "$(_w_clean_display "${path}"): not empty, left in place"
        fi
        ;;
      dir)
        if _w_clean_dir_empty "${path}"; then
          w_remove_dir "${path}"
        else
          w_log_info "$(_w_clean_display "${path}"): not empty, left in place"
        fi
        ;;
    esac
  done
}

# Remove the pub-era .bashrc blocks, asking before each one.
#
# Editing an rc file is the only thing clean does that is not a plain deletion,
# so it always prompts, even under --apply, and always leaves a backup.
_w_clean_apply_blocks() {
  local block start_re end_re description range reply
  for block in "${W_CLEAN_BASHRC_BLOCKS[@]}"; do
    IFS='|' read -r start_re end_re description <<< "${block}"
    range=$(w_block_range "${HOME}/.bashrc" "${start_re}" "${end_re}")
    [[ -n "${range}" ]] || continue

    reply=$(w_prompt "Remove lines ${range% *}-${range#* } from ~/.bashrc (${description})? [y/N]")
    case "${reply}" in
      y|Y|yes|YES) w_remove_block "${HOME}/.bashrc" "${start_re}" "${end_re}" ;;
      *)           w_log_info "Left ~/.bashrc unchanged." ;;
    esac
  done
}

# Report artefacts left by earlier versions of war10ck, and remove them with
# --apply. Reporting is the default because the list is worth seeing on its
# own: it is the only view of what a long-lived install has accumulated.
#
# Arguments:
#   $@ - flags, currently only --apply
clean() {
  local apply=0
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --apply) apply=1 ;;
      *)
        w_log_error "Unknown clean option: ${arg}"
        w_log_error "Usage: war10ck clean [--apply]"
        return 1
        ;;
    esac
  done

  if ! _w_clean_report; then
    w_log_info "Nothing to clean."
    return 0
  fi

  if (( apply == 0 )); then
    w_log_info "Run 'war10ck clean --apply' to remove these."
    return 0
  fi

  _w_clean_apply_paths
  _w_clean_apply_blocks
  w_log_info "Clean complete."
}
