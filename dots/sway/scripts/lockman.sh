#!/bin/sh
# Lock now; turn outputs off after 5 min while locked.
swayidle \
    timeout 300 'swaymsg "output * power off"' \
    resume 'swaymsg "output * power on"' &
idle_pid=$!
# Stop the idle timer however swaylock exits (unlock or crash)
trap 'kill "$idle_pid" 2>/dev/null; swaymsg "output * power on" >/dev/null 2>&1' EXIT
swaylock
