#!/usr/bin/env bash
# One-shot workspace notification for awesomewm.

set -euo pipefail

command -v awesome-client >/dev/null 2>&1 || exit 0

current=$(awesome-client 'local awful=require("awful"); local s=awful.screen.focused(); local t=s and s.selected_tag; if t and t.name then io.write(t.name) end' 2>/dev/null || true)
current=$(printf "%s" "$current" | tr -d '\r\n')
[ -n "$current" ] || exit 0

NOTIFY_ID=99994
QUICK_TIMEOUT=1100

if command -v dunstify >/dev/null 2>&1; then
    dunstify -r "$NOTIFY_ID" -u low -t "$QUICK_TIMEOUT" "Workspace $current" ""
elif command -v notify-send >/dev/null 2>&1; then
    if notify-send --help 2>&1 | grep -q -- '--replace-id'; then
        notify-send --replace-id="$NOTIFY_ID" -u low -t "$QUICK_TIMEOUT" "Workspace $current" ""
    else
        notify-send -u low -t "$QUICK_TIMEOUT" -h "string:x-dunst-stack-tag:workspace-notify" "Workspace $current" ""
    fi
fi
