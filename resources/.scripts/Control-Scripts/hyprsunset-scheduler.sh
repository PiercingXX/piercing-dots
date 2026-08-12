#!/bin/bash

set -u

# Single-instance guard. Without this the session can end up running several
# copies, each independently poking the compositor.
exec 9>/tmp/hyprsunset-scheduler.lock
if ! flock -n 9; then
    exit 0
fi

# Warm filter from 20:00 through 03:59, neutral from 04:00 through 19:59.
want_state() {
    local hhmm
    hhmm="$(date +%H%M)"
    if [[ "10#$hhmm" -ge 2000 || "10#$hhmm" -lt 400 ]]; then
        echo warm
    else
        echo neutral
    fi
}

apply() {
    case "$1" in
        warm)    hyprctl hyprsunset temperature 2200 >/dev/null 2>&1 || true ;;
        neutral) hyprctl hyprsunset identity          >/dev/null 2>&1 || true ;;
    esac
}

applied=""

while true; do
    # Restart the daemon only if it actually died. If it did, force a reapply
    # since a fresh daemon comes up with no filter.
    if ! pgrep -x hyprsunset >/dev/null 2>&1; then
        hyprsunset >/tmp/hyprsunset.log 2>&1 &
        sleep 1
        applied=""
    fi

    state="$(want_state)"

    # Only talk to the compositor when the state actually changes. Reapplying
    # the same temperature forces a display reconfigure that stalls every
    # client on screen for a moment - which at a 60s cadence reads as a
    # periodic freeze in games and video playback.
    if [[ "$state" != "$applied" ]]; then
        apply "$state"
        applied="$state"
    fi

    sleep 60
done
