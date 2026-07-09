#!/usr/bin/env bash
# Workspace switch notification daemon for herbstluftwm.

set -euo pipefail

LOCK_DIR="${XDG_RUNTIME_DIR:-/tmp}"
LOCK_FILE="$LOCK_DIR/workspace-notify-herbst.lock"
mkdir -p "$(dirname "$LOCK_FILE")"
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

NOTIFY_ID=99992
QUICK_TIMEOUT=1100

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
    current=$(herbstclient attr tags.focus.name 2>/dev/null || true)
    [[ -n "$current" ]] || return 0

    body=$(herbstclient tag_status 2>/dev/null | sed 's/\s\+/\n/g' | while read -r tag; do
        prefix="${tag:0:1}"
        name="${tag:1}"
        case "$prefix" in
            '#' ) echo "[$name]" ;;
            ':'|'+' ) echo "$name" ;;
        esac
    done | tr '\n' ' ' | sed 's/[[:space:]]*$//')

    if [[ "$NOTIFY_BIN" == "dunstify" ]]; then
        dunstify -r "$NOTIFY_ID" -u low -t "$QUICK_TIMEOUT" "Workspace $current" "Open: $body"
    elif [[ "${NOTIFY_REPLACE:-false}" == true ]]; then
        notify-send --replace-id="$NOTIFY_ID" -u low -t "$QUICK_TIMEOUT" "Workspace $current" "Open: $body"
    else
        notify-send -u low -t "$QUICK_TIMEOUT" -h "string:x-dunst-stack-tag:workspace-notify" "Workspace $current" "Open: $body"
    fi
}

notify_ws
herbstclient --idle 'focus_changed|tag_changed' 2>/dev/null | while IFS= read -r _; do
    notify_ws
done
