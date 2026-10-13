#!/bin/bash
# GitHub.com/PiercingXX
# Screen brightness keys with an on-screen bubble.
# Usage: brightness.sh inc|dec|get
# Hotkey script: never installs packages, just tells you what's missing.

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

STEP=10

case "${1:-}" in
    inc) change="+${STEP}%" ;;
    dec) change="${STEP}%-" ;;
    get) change="" ;;
    *) printf 'Usage: %s [inc|dec|get]\n' "$(basename "$0")" >&2; exit 1 ;;
esac

if ! command_exists brightnessctl; then
    notify_replace brightness normal 3000 dialog-error "Brightness" "brightnessctl is not installed."
    exit 1
fi

# Only touch backlights (default device can be a keyboard LED on desktops)
if ! brightnessctl -c backlight -m >/dev/null 2>&1; then
    [ "$1" = get ] && { echo 0; exit 0; }
    notify_replace brightness low 2000 display-brightness "Brightness" "No backlight device found."
    exit 0
fi

# -m prints machine output: device,class,current,percent%,max
if [ -n "$change" ]; then
    line=$(brightnessctl -c backlight -m set "$change")
else
    line=$(brightnessctl -c backlight -m)
fi
percent=$(printf '%s' "$line" | head -n1 | cut -d, -f4 | tr -d '%')
percent=${percent:-0}

if [ "$1" = get ]; then
    echo "$percent"
    exit 0
fi

if (( percent == 0 )); then
    icon="display-brightness-off"
elif (( percent < 30 )); then
    icon="display-brightness-low"
elif (( percent < 70 )); then
    icon="display-brightness-medium"
else
    icon="display-brightness-high"
fi

osd "$icon" "Brightness ${percent}%" "$percent"
