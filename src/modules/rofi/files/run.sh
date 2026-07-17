#!/usr/bin/env bash
# One-off command runner - displayed via rofi dmenu.
# Lists bash history most-recent-first, then everything on $PATH. Anything
# typed that is not in the list runs as-is, so flags and arguments work.
# Launch with: mod+Shift+d

HISTORY_FILE="${HISTFILE:-$HOME/.bash_history}"

# HISTTIMEFORMAT makes bash write a "#<epoch>" line before every entry, and
# lithist keeps multi-line commands as literal newlines. Treat the markers as
# entry delimiters and emit only single-line entries, since rofi is line-based
# and a fragment of a loop body is not something worth re-running.
history_entries() {
    [[ -r "$HISTORY_FILE" ]] || return 0
    awk '
        /^#[0-9]+$/ { if (lines == 1) print entry; lines = 0; entry = ""; next }
        { if (lines == 0) { entry = $0; lines = 1 } else { lines = 2 } }
        END { if (lines == 1) print entry }
    ' "$HISTORY_FILE" | tac
}

# History first so recent commands outrank bare binaries when rofi filters.
# HISTCONTROL is only ignoredups (consecutive), so the file repeats heavily.
candidates() {
    {
        history_entries
        compgen -c | sort -u
    } | awk 'NF && !seen[$0]++'
}

cmd=$(candidates | rofi \
    -config "$HOME/.war10ck/rofi/config.rasi" \
    -dmenu \
    -i \
    -p "run" \
    -theme-str 'entry { placeholder: "Run a command..."; }' \
    -theme-str 'element { children: [ element-text ]; }' \
    -theme-str 'textbox-help { content: " Enter to run  │  Esc to close"; }')

[[ -n "$cmd" ]] || exit 0

# Detach from rofi entirely: no controlling terminal, no stdio. Nothing is
# sourced, so aliases and shell functions are unavailable here. Failures would
# otherwise be silent, so stderr is captured and pushed to dunst instead.
# shellcheck disable=SC2016  # $1 is expanded by the inner shell, not this one
setsid --fork bash -c '
    err=$(eval "$1" 2>&1 >/dev/null)
    status=$?
    (( status == 0 )) || notify-send -u critical -a "rofi-run" \
        "Command failed (exit $status)" "${err:0:400}"
' rofi-run "$cmd" </dev/null >/dev/null 2>&1
