#!/bin/bash
# GitHub.com/PiercingXX
# Battery level notification daemon.
# Notifies at 40%, 30%, 20%, and 10% while discharging, plus plug/unplug.
# Event-driven via upower or udev; falls back to polling sysfs.
# Exits silently on desktops (no battery present).

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

POLL_INTERVAL=60  # safety re-check even when events are flowing
STATE_TIMEOUT=2200
CRITICAL_TIMEOUT=7000
THRESHOLDS=(10 20 30 40)  # ascending

# --- Find battery path ---
BAT_PATH=""
for p in /sys/class/power_supply/BAT0 \
          /sys/class/power_supply/BAT1 \
          /sys/class/power_supply/BATT \
          /sys/class/power_supply/battery; do
    [ -d "$p" ] && BAT_PATH="$p" && break
done

# No battery = desktop machine, exit cleanly
[ -z "$BAT_PATH" ] && exit 0

single_instance battery-notify || exit 0

LAST_NOTIFIED=100  # lowest threshold already notified this discharge cycle
LAST_STATUS=$(cat "$BAT_PATH/status" 2>/dev/null)

check_battery() {
    local level status
    level=$(cat "$BAT_PATH/capacity" 2>/dev/null)
    status=$(cat "$BAT_PATH/status" 2>/dev/null)
    [[ "$level" =~ ^[0-9]+$ ]] || return 0

    if [[ -n "$status" && "$status" != "$LAST_STATUS" ]]; then
        case "$status" in
            Charging)
                notify_replace battery-state low "$STATE_TIMEOUT" battery-good-charging "Power connected" "Charging (${level}%)" ;;
            Discharging)
                notify_replace battery-state low "$STATE_TIMEOUT" battery-low "On battery" "Discharging (${level}%)" ;;
            Full)
                notify_replace battery-state low "$STATE_TIMEOUT" battery-full-charged "Battery full" "100%" ;;
            "Not charging")
                notify_replace battery-state low "$STATE_TIMEOUT" battery "Power state changed" "Not charging (${level}%)" ;;
        esac
        LAST_STATUS="$status"
    fi

    if [[ "$status" == "Discharging" ]]; then
        # Lowest threshold crossed since the last notification, one bubble only
        local threshold crossed=""
        for threshold in "${THRESHOLDS[@]}"; do
            if (( level <= threshold && LAST_NOTIFIED > threshold )); then
                crossed=$threshold
                break
            fi
        done
        if [ -n "$crossed" ]; then
            LAST_NOTIFIED=$crossed
            if (( crossed <= 20 )); then
                notify_replace battery critical "$CRITICAL_TIMEOUT" battery-caution "Battery ${level}%" "Plug in soon."
            else
                notify_replace battery low "$STATE_TIMEOUT" battery-low "Battery ${level}%" "Plug in soon."
            fi
        fi
    else
        # Charging or Full — reset so we notify again next discharge cycle
        LAST_NOTIFIED=100
    fi
}

# Event source: any line means "something changed, re-read sysfs"
event_source() {
    if command_exists upower; then
        exec upower --monitor
    elif command_exists udevadm; then
        exec udevadm monitor --udev --subsystem-match=power_supply
    else
        # No event source: emit a tick every interval
        while sleep "$POLL_INTERVAL"; do echo tick; done
    fi
}

check_battery
while true; do
    # read -t gives a periodic re-check even if the event stream is quiet
    while IFS= read -r -t "$POLL_INTERVAL" _ || [ $? -gt 128 ]; do
        check_battery
    done < <(event_source)
    # Event source died (upowerd restarted, etc.); back off and reconnect
    sleep 5
done
