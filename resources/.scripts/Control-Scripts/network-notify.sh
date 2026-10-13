#!/bin/bash
# GitHub.com/PiercingXX
# Network status notification daemon (any WM; needs NetworkManager).

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

POLL_INTERVAL=30   # safety re-check; nmcli monitor delivers changes instantly
STATE_TIMEOUT=2200

if ! command_exists nmcli; then
    echo "network-notify: nmcli not found." >&2
    exit 1
fi

single_instance network-notify || exit 0

notify() {
    local summary="$1" body="$2" icon="$3" urgency="$4"
    notify_replace network "$urgency" "$STATE_TIMEOUT" "$icon" "$summary" "$body"
}

# Fields are joined with a unit separator (\x1f) so SSIDs containing '|' or ':' survive
SEP=$'\x1f'
snapshot_state() {
    local state wifi_ssid eth_dev
    state=$(nmcli -t -f STATE general 2>/dev/null)
    # -t escapes ':' inside values as '\:'; split on unescaped ':' only
    wifi_ssid=$(nmcli -t -f ACTIVE,SSID dev wifi list --rescan no 2>/dev/null \
        | sed -n 's/^yes://p' | head -n 1 | sed 's/\\:/:/g')
    eth_dev=$(nmcli -t -f DEVICE,TYPE,STATE dev status 2>/dev/null | awk -F: '$2=="ethernet" && $3=="connected" {print $1; exit}')
    printf '%s%s%s%s%s\n' "$state" "$SEP" "$wifi_ssid" "$SEP" "$eth_dev"
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
        connected*)
            SUMMARY="Network - Connected"
            BODY="Connection active"
            ICON="network-transmit-receive"
            URGENCY="low"
            ;;
        connecting*)
            SUMMARY="Network - Connecting"
            BODY="Trying to establish a connection"
            ICON="network-idle"
            URGENCY="low"
            ;;
        disconnected*)
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

check_network() {
    local current state wifi_ssid eth_dev
    current="$(snapshot_state)"
    [[ "$current" == "$last" ]] && return 0
    IFS="$SEP" read -r state wifi_ssid eth_dev <<< "$current"
    build_message "$state" "$wifi_ssid" "$eth_dev"
    notify "$SUMMARY" "$BODY" "$ICON" "$URGENCY"
    last="$current"
}

last="$(snapshot_state)"

while true; do
    # nmcli monitor prints a line on every state change; read -t keeps a slow
    # periodic re-check in case the monitor stream stalls.
    while IFS= read -r -t "$POLL_INTERVAL" _ || [ $? -gt 128 ]; do
        check_network
    done < <(nmcli monitor 2>/dev/null)
    sleep 5
done
