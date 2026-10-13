#!/bin/bash
# GitHub.com/PiercingXX
# Bluetooth status notification daemon (any WM; needs bluez).
# Event-driven via the bluez D-Bus signals; falls back to polling.

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

POLL_INTERVAL=5      # only used when dbus-monitor is missing
RECHECK_INTERVAL=60  # safety re-check while the event stream is quiet
STATE_TIMEOUT=2200

if ! command_exists bluetoothctl; then
    echo "bluetooth-notify: bluetoothctl not found." >&2
    exit 1
fi

single_instance bluetooth-notify || exit 0

notify() {
    local summary="$1" body="$2" icon="$3" urgency="$4"
    notify_replace bluetooth "$urgency" "$STATE_TIMEOUT" "$icon" "$summary" "$body"
}

SEP=$'\x1f'
get_snapshot() {
    local powered connected
    powered=$(bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ {print $2; exit}')
    connected=$(bluetoothctl devices Connected 2>/dev/null | sed 's/^Device [^ ]* //' \
        | paste -sd ',' - | sed 's/,/, /g')
    printf '%s%s%s\n' "$powered" "$SEP" "$connected"
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

check_bluetooth() {
    local current powered connected
    current="$(get_snapshot)"
    [[ "$current" == "$last" ]] && return 0
    IFS="$SEP" read -r powered connected <<< "$current"
    build_message "$powered" "$connected"
    notify "$SUMMARY" "$BODY" "$ICON" "$URGENCY"
    last="$current"
}

event_source() {
    if command_exists dbus-monitor; then
        exec dbus-monitor --system \
            "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'" \
            "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.ObjectManager'" 2>/dev/null
    else
        while sleep "$POLL_INTERVAL"; do echo tick; done
    fi
}

last="$(get_snapshot)"

while true; do
    while IFS= read -r -t "$RECHECK_INTERVAL" _ || [ $? -gt 128 ]; do
        # One state change emits a burst of signals; drain it before re-reading
        while IFS= read -r -t 0.5 _; do :; done
        check_bluetooth
    done < <(event_source)
    sleep 5
done
