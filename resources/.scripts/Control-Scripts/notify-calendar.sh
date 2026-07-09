#!/bin/bash

NOTIFY_ID=99987
STATE_TIMEOUT=6000
MONTH_TITLE="$(date '+%B %Y')"

if command -v cal &>/dev/null; then
    CAL_BODY="$(cal)"
else
    CAL_BODY="Calendar utility not found"
fi

if command -v dunstify &>/dev/null; then
    dunstify -r "$NOTIFY_ID" -u low -t "$STATE_TIMEOUT" "$MONTH_TITLE" "$CAL_BODY"
elif command -v notify-send &>/dev/null; then
    if notify-send --help 2>&1 | grep -q -- '--replace-id'; then
        notify-send --replace-id="$NOTIFY_ID" -u low -t "$STATE_TIMEOUT" "$MONTH_TITLE" "$CAL_BODY"
    else
        notify-send -u low -t "$STATE_TIMEOUT" -h "string:x-dunst-stack-tag:calendar-notify" "$MONTH_TITLE" "$CAL_BODY"
    fi
else
    printf '%s\n%s\n' "$MONTH_TITLE" "$CAL_BODY"
fi
