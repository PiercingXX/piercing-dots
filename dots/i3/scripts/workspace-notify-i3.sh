#!/usr/bin/env bash
# Workspace switch notification daemon for i3.

set -euo pipefail

LOCK_DIR="${XDG_RUNTIME_DIR:-/tmp}"
LOCK_FILE="$LOCK_DIR/workspace-notify-i3.lock"
mkdir -p "$(dirname "$LOCK_FILE")"
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

NOTIFY_ID=99993
QUICK_TIMEOUT=1100

for tool in i3-msg jq; do
    command -v "$tool" >/dev/null 2>&1 || exit 0
done

if command -v dunstify >/dev/null 2>&1; then
    NOTIFY_BIN="dunstify"
elif command -v notify-send >/dev/null 2>&1; then
    NOTIFY_BIN="notify-send"
    if notify-send --help 2>&1 | grep -q -- '--replace-id'; then
        NOTIFY_REPLACE=true
    else
        NOTIFY_REPLACE=false
    fi
else
    exit 0
fi

notify_ws() {
    local current body
    current=$(i3-msg -t get_workspaces -r 2>/dev/null | jq -r '.[] | select(.focused==true) | .name' | head -n1)
    [[ -n "$current" && "$current" != "null" ]] || return 0

    body=$(i3-msg -t get_workspaces -r 2>/dev/null | jq -r '.[] | select(.visible==true or .focused==true or .urgent==true) | .name' | tr '\n' ' ' | sed 's/[[:space:]]*$//')

    if [[ "$NOTIFY_BIN" == "dunstify" ]]; then
        dunstify -r "$NOTIFY_ID" -u low -t "$QUICK_TIMEOUT" "Workspace $current" "Open: $body"
    elif [[ "${NOTIFY_REPLACE:-false}" == true ]]; then
        notify-send --replace-id="$NOTIFY_ID" -u low -t "$QUICK_TIMEOUT" "Workspace $current" "Open: $body"
    else
        notify-send -u low -t "$QUICK_TIMEOUT" -h "string:x-dunst-stack-tag:workspace-notify" "Workspace $current" "Open: $body"
    fi
}

notify_ws
i3-msg -t subscribe -m '["workspace","output"]' 2>/dev/null | while IFS= read -r _; do
    notify_ws
done
