#!/bin/bash

NOTIFY_ID=99986
STATE_TIMEOUT=2500
TIME_TEXT="$(date '+%H:%M:%S')"
DATE_TEXT="$(date '+%a %b %d')"

if command -v dunstify &>/dev/null; then
    dunstify -r "$NOTIFY_ID" -u low -t "$STATE_TIMEOUT" "$TIME_TEXT" "$DATE_TEXT"
elif command -v notify-send &>/dev/null; then
    if notify-send --help 2>&1 | grep -q -- '--replace-id'; then
        notify-send --replace-id="$NOTIFY_ID" -u low -t "$STATE_TIMEOUT" "$TIME_TEXT" "$DATE_TEXT"
    else
        notify-send -u low -t "$STATE_TIMEOUT" -h "string:x-dunst-stack-tag:time-notify" "$TIME_TEXT" "$DATE_TEXT"
    fi
else
    printf '%s %s\n' "$TIME_TEXT" "$DATE_TEXT"
fi
