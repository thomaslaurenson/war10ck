#!/usr/bin/env bash
# Polybar Claude Code usage module.
#
# Prints the percentage of the current session or weekly limit already used,
# with the time left before that window resets appended. Prints nothing
# when claude is missing, unauthenticated, or unparseable - polybar hides a
# custom/script module whose output is empty.
#
# Usage: claude-usage.sh session|week

FIELD="${1:-session}"

# Both fields, both bars and every monitor share one cached answer: querying
# claude takes a couple of seconds and there is no point doing it four times.
CACHE="${XDG_RUNTIME_DIR:-/tmp}/war10ck-claude-usage-${UID}"
# The session module ticks every minute so its countdown stays live, but claude
# itself is only asked once per TTL.
TTL=280

# polybar inherits i3's environment, which does not always carry ~/.local/bin.
PATH="$HOME/.local/bin:$PATH"

command -v claude >/dev/null 2>&1 || exit 0

# Read one key out of the cache. Prints nothing when the key is absent.
#
# Arguments:
#   $1 - Key to look up
cache_get() {
    local want=$1 key value
    [[ -s "$CACHE" ]] || return 0
    while IFS='=' read -r key value; do
        [[ "$key" == "$want" ]] && printf '%s\n' "$value"
    done < "$CACHE"
    return 0
}

# Convert a reset timestamp as claude prints it into seconds since the epoch.
#
# Arguments:
#   $1 - Time of day, e.g. "Aug 6, 5:30pm" (the minutes are dropped on the hour)
#   $2 - IANA zone name, e.g. "Pacific/Auckland"
reset_epoch() {
    local when=$1 zone=$2 year epoch now
    when="${when%"${when##*[![:space:]]}"}"
    # GNU date parses the time of day happily but rejects the comma.
    when="${when//,/}"

    # An unknown zone name makes date fall back to UTC without complaining,
    # which would be hours wrong. claude reports the machine's own zone, so
    # local time is the right thing to fall back to instead.
    local -a tz=()
    [[ -e "/usr/share/zoneinfo/$zone" ]] && tz=(env "TZ=$zone")

    # The line carries no year, and "Jan 1" read on New Year's Eve lands a year
    # in the past. A session window is a few hours long, so a reset that far
    # back is the rollover rather than one that has genuinely been and gone.
    year=$("${tz[@]}" date +%Y)
    epoch=$("${tz[@]}" date -d "$when $year" +%s 2>/dev/null) || return 1
    now=$(date +%s)
    if (( epoch < now - 43200 )); then
        epoch=$("${tz[@]}" date -d "$when $((year + 1))" +%s 2>/dev/null) || return 1
    fi

    printf '%s\n' "$epoch"
}

# Render the time left until a reset as "(43m)", "(4h47m)" past the hour, or
# "(3d22h)" past the day - a session window runs to five hours and a weekly one
# to seven days, and "(287m)" or "(94h)" are harder to read at a glance.
# Returns non-zero once the reset is in the past.
#
# Arguments:
#   $1 - Reset time in seconds since the epoch
format_countdown() {
    local left mins
    left=$(( $1 - $(date +%s) ))
    (( left > 0 )) || return 1
    # Rounded up, so the last minute of a window never reads as "(0m)".
    mins=$(( (left + 59) / 60 ))
    if (( mins < 60 )); then
        printf '(%dm)\n' "$mins"
    elif (( mins < 1440 )); then
        printf '(%dh%02dm)\n' $(( mins / 60 )) $(( mins % 60 ))
    else
        printf '(%dd%02dh)\n' $(( mins / 1440 )) $(( mins % 1440 / 60 ))
    fi
}

# Query claude and rewrite the cache. Returns non-zero without touching the
# cache if the output holds no percentages, which is what an unauthenticated
# or otherwise unhappy claude produces.
refresh() {
    local output line session="" week="" session_reset="" week_reset=""
    local re_session='^Current session: +([0-9]+)%'
    local re_week='^Current week \(all models\): +([0-9]+)%'
    local re_reset='resets ([^(]+) \(([^)]+)\)'

    output=$(timeout 60 claude -p "/usage" 2>/dev/null) || return 1

    while IFS= read -r line; do
        if [[ "$line" =~ $re_session ]]; then
            session="${BASH_REMATCH[1]}"
            # Matched separately so a missing or reworded reset clause costs
            # the countdown only, not the percentage.
            if [[ "$line" =~ $re_reset ]]; then
                session_reset=$(reset_epoch "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}") \
                    || session_reset=""
            fi
        elif [[ "$line" =~ $re_week ]]; then
            week="${BASH_REMATCH[1]}"
            if [[ "$line" =~ $re_reset ]]; then
                week_reset=$(reset_epoch "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}") || week_reset=""
            fi
        fi
    done <<< "$output"

    [[ -n "$session" && -n "$week" ]] || return 1
    printf 'session=%s\nweek=%s\nsession_reset=%s\nweek_reset=%s\n' \
        "$session" "$week" "$session_reset" "$week_reset" > "$CACHE"
}

is_stale() {
    local mtime now reset
    [[ -s "$CACHE" ]] || return 0
    mtime=$(stat -c %Y "$CACHE" 2>/dev/null) || return 0
    now=$(date +%s)
    (( now - mtime > TTL )) && return 0

    # A window rolled over while the cache sat there, so the percentage in it
    # belongs to a session or week that has already ended.
    for reset in $(cache_get session_reset) $(cache_get week_reset); do
        (( now >= reset )) && return 0
    done
    return 1
}

# Serialise refreshes: the modules that wake up second wait here and then read
# the answer the first one fetched, rather than running claude all over again.
exec 9>"$CACHE.lock"
flock 9
if is_stale; then
    # Drop the cache when a refresh fails - showing a percentage from an hour
    # ago is worse than showing nothing.
    refresh || rm -f "$CACHE"
fi
flock -u 9

value=$(cache_get "$FIELD")
[[ -n "$value" ]] || exit 0

countdown=""
reset=$(cache_get "${FIELD}_reset")
if [[ -n "$reset" ]]; then
    countdown=$(format_countdown "$reset") || countdown=""
fi

printf '%s%%%s\n' "$value" "${countdown:+ $countdown}"
