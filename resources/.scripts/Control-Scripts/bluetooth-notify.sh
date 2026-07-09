#!/bin/bash
# GitHub.com/PiercingXX
# Bluetooth status notification daemon for Hyprland.

NOTIFY_ID=99981
POLL_INTERVAL=5
STATE_TIMEOUT=2200

if ! command -v bluetoothctl &>/dev/null; then
    echo "bluetooth-notify: bluetoothctl not found." >&2
    exit 1
fi

if command -v dunstify &>/dev/null; then
    NOTIFY_BIN="dunstify"
elif command -v notify-send &>/dev/null; then
    NOTIFY_BIN="notify-send"
    notify-send --help 2>&1 | grep -q -- '--replace-id' && NOTIFY_REPLACE=true || NOTIFY_REPLACE=false
else
    echo "bluetooth-notify: need dunstify or notify-send." >&2
    exit 1
fi

notify() {
    local summary="$1" body="$2" icon="$3" urgency="$4"
    if [[ "$NOTIFY_BIN" == "dunstify" ]]; then
        dunstify -r "$NOTIFY_ID" -u "$urgency" -t "$STATE_TIMEOUT" -i "$icon" "$summary" "$body"
    elif [[ "${NOTIFY_REPLACE:-false}" == true ]]; then
        notify-send --replace-id="$NOTIFY_ID" -u "$urgency" -t "$STATE_TIMEOUT" -i "$icon" "$summary" "$body"
    else
        notify-send -u "$urgency" -t "$STATE_TIMEOUT" -i "$icon" -h "string:x-dunst-stack-tag:bluetooth-notify" "$summary" "$body"
    fi
}

get_snapshot() {
    local powered connected
    powered=$(bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ {print $2; exit}')
    connected=$(bluetoothctl devices Connected 2>/dev/null | sed 's/^Device [^ ]* //')
    connected=$(echo "$connected" | paste -sd ', ' -)
    printf '%s|%s\n' "$powered" "$connected"
}

build_message() {
    local powered="$1" connected="$2"
    if [[ "$powered" != "yes" ]]; then
        SUMMARY="Bluetooth - Off"
        BODY="Adapter is powered off"
        ICON="bluetooth-disabled"
        URGENCY="low"
        return
    fi

    if [[ -n "$connected" ]]; then
        SUMMARY="Bluetooth - Connected"
        BODY="$connected"
        ICON="bluetooth-active"
        URGENCY="low"
    else
        SUMMARY="Bluetooth - On"
        BODY="No connected devices"
        ICON="bluetooth"
        URGENCY="low"
    fi
}

last="$(get_snapshot)"

while true; do
    current="$(get_snapshot)"
    if [[ "$current" != "$last" ]]; then
        IFS='|' read -r powered connected <<< "$current"
        build_message "$powered" "$connected"
        notify "$SUMMARY" "$BODY" "$ICON" "$URGENCY"
        last="$current"
    fi
    sleep "$POLL_INTERVAL"
done
