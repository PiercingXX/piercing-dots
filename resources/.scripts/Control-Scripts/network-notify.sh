#!/bin/bash
# GitHub.com/PiercingXX
# Network status notification daemon for Hyprland.

NOTIFY_ID=99980
POLL_INTERVAL=5
STATE_TIMEOUT=2200

if ! command -v nmcli &>/dev/null; then
    echo "network-notify: nmcli not found." >&2
    exit 1
fi

if command -v dunstify &>/dev/null; then
    NOTIFY_BIN="dunstify"
elif command -v notify-send &>/dev/null; then
    NOTIFY_BIN="notify-send"
    notify-send --help 2>&1 | grep -q -- '--replace-id' && NOTIFY_REPLACE=true || NOTIFY_REPLACE=false
else
    echo "network-notify: need dunstify or notify-send." >&2
    exit 1
fi

notify() {
    local summary="$1" body="$2" icon="$3" urgency="$4"
    if [[ "$NOTIFY_BIN" == "dunstify" ]]; then
        dunstify -r "$NOTIFY_ID" -u "$urgency" -t "$STATE_TIMEOUT" -i "$icon" "$summary" "$body"
    elif [[ "${NOTIFY_REPLACE:-false}" == true ]]; then
        notify-send --replace-id="$NOTIFY_ID" -u "$urgency" -t "$STATE_TIMEOUT" -i "$icon" "$summary" "$body"
    else
        notify-send -u "$urgency" -t "$STATE_TIMEOUT" -i "$icon" -h "string:x-dunst-stack-tag:network-notify" "$summary" "$body"
    fi
}

snapshot_state() {
    local state wifi_ssid eth_dev
    state=$(nmcli -t -f STATE general 2>/dev/null)
    wifi_ssid=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1=="yes" {print $2; exit}')
    eth_dev=$(nmcli -t -f DEVICE,TYPE,STATE dev status 2>/dev/null | awk -F: '$2=="ethernet" && $3=="connected" {print $1; exit}')
    printf '%s|%s|%s\n' "$state" "$wifi_ssid" "$eth_dev"
}

build_message() {
    local state="$1" wifi_ssid="$2" eth_dev="$3"

    if [[ -n "$eth_dev" ]]; then
        SUMMARY="Network - Ethernet"
        BODY="Connected on ${eth_dev}"
        ICON="network-wired"
        URGENCY="low"
        return
    fi

    if [[ -n "$wifi_ssid" ]]; then
        SUMMARY="Network - Wi-Fi"
        BODY="Connected to ${wifi_ssid}"
        ICON="network-wireless"
        URGENCY="low"
        return
    fi

    case "$state" in
        connected|connected*)
            SUMMARY="Network - Connected"
            BODY="Connection active"
            ICON="network-transmit-receive"
            URGENCY="low"
            ;;
        connecting|connecting*)
            SUMMARY="Network - Connecting"
            BODY="Trying to establish a connection"
            ICON="network-idle"
            URGENCY="low"
            ;;
        disconnected|disconnected*)
            SUMMARY="Network - Disconnected"
            BODY="No active network connection"
            ICON="network-offline"
            URGENCY="low"
            ;;
        *)
            SUMMARY="Network - ${state}"
            BODY="State changed"
            ICON="network-workgroup"
            URGENCY="low"
            ;;
    esac
}

last="$(snapshot_state)"

while true; do
    current="$(snapshot_state)"
    if [[ "$current" != "$last" ]]; then
        IFS='|' read -r state wifi_ssid eth_dev <<< "$current"
        build_message "$state" "$wifi_ssid" "$eth_dev"
        notify "$SUMMARY" "$BODY" "$ICON" "$URGENCY"
        last="$current"
    fi
    sleep "$POLL_INTERVAL"
done
