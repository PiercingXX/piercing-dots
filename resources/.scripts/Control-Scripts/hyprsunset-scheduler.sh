#!/bin/bash

set -u

while true; do
    # Start hyprsunset daemon if it is not already running.
    pgrep -x hyprsunset >/dev/null 2>&1 || hyprsunset >/tmp/hyprsunset.log 2>&1 &

    # Give the daemon a moment to create its socket before sending IPC commands.
    sleep 1

    hhmm="$(date +%H%M)"

    # Warm filter from 20:00 through 03:59, neutral from 04:00 through 19:59.
    if [[ "$hhmm" -ge 2000 || "$hhmm" -lt 0400 ]]; then
        hyprctl hyprsunset temperature 2200 >/dev/null 2>&1 || true
    else
        hyprctl hyprsunset identity >/dev/null 2>&1 || true
    fi

    sleep 60
done
