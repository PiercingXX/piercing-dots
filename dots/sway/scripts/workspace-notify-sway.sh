#!/bin/bash
# GitHub.com/PiercingXX
# Sway workspace switch notification daemon.

set -euo pipefail

LOCK_DIR="${XDG_RUNTIME_DIR:-/tmp}"
LOCK_FILE="$LOCK_DIR/workspace-notify-sway.lock"
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

NOTIFY_ID=99991
QUICK_TIMEOUT=1100

for tool in jq swaymsg; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "workspace-notify-sway: $tool not found" >&2
        exit 1
    fi
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
    echo "workspace-notify-sway: need dunstify or notify-send" >&2
    exit 1
fi

notify() {
    local rid="$1" urgency="$2" timeout="$3" summary="$4" body="$5"
    if [[ "$NOTIFY_BIN" == "dunstify" ]]; then
        dunstify -r "$rid" -u "$urgency" -t "$timeout" "$summary" "$body"
    elif [[ "${NOTIFY_REPLACE:-false}" == true ]]; then
        notify-send --replace-id="$rid" -u "$urgency" -t "$timeout" "$summary" "$body"
    else
        notify-send -u "$urgency" -t "$timeout" \
            -h "string:x-dunst-stack-tag:workspace-notify" \
            "$summary" "$body"
    fi
}

update_swaync_monitor() {
    command -v swaync-client >/dev/null 2>&1 || return 0

    local focused_output
    focused_output=$(swaymsg -t get_outputs -r 2>/dev/null | jq -r '.[] | select(.focused==true) | .name' | head -n1)
    [[ -n "$focused_output" && "$focused_output" != "null" ]] || return 0

    swaync-client --change-noti-monitor "$focused_output" -sw >/dev/null 2>&1 || true
    swaync-client --change-cc-monitor "$focused_output" -sw >/dev/null 2>&1 || true
}

notify_workspace() {
    local current
    current=$(swaymsg -t get_workspaces -r 2>/dev/null | jq -r '.[] | select(.focused==true) | .name' | head -n1)
    [[ -n "$current" && "$current" != "null" ]] || return 0

    mapfile -t occupied < <(
        swaymsg -t get_tree -r 2>/dev/null \
            | jq -r '.. | objects
                | select(.type? == "workspace")
                | select((((.nodes // []) | length) + ((.floating_nodes // []) | length)) > 0)
                | .name' \
            | awk 'NF' \
            | awk '!/#/' \
            | sort -u \
            | sort -V
    )

    local found=false
    local parts=()
    local ws
    for ws in "${occupied[@]}"; do
        if [[ "$ws" == "$current" ]]; then
            parts+=("[$ws]")
            found=true
        else
            parts+=("$ws")
        fi
    done

    if [[ "$found" == false ]]; then
        parts+=("[$current]")
    fi

    local body
    body=$(printf '%s\n' "${parts[@]}" \
        | sort -t'[' -k1,1 -V \
        | tr '\n' ' ' \
        | sed 's/[[:space:]]*$//')
    notify "$NOTIFY_ID" low "$QUICK_TIMEOUT" "Workspace $current" "Open: $body"
}

update_swaync_monitor
notify_workspace

swaymsg -t subscribe -m '["workspace","output"]' 2>/dev/null | while IFS= read -r _; do
    update_swaync_monitor
    notify_workspace
done
