#!/bin/bash
# GitHub.com/PiercingXX
# Battery level notification daemon.
# Notifies at 40%, 30%, 20%, and 10% while discharging.
# Exits silently on desktops (no battery present).

NOTIFY_ID=99992
STATUS_NOTIFY_ID=99993
POLL_INTERVAL=60  # seconds between checks
STATE_TIMEOUT=2200
CRITICAL_TIMEOUT=7000

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

# Notification backend: dunstify (replace-ID support) > notify-send
if command -v dunstify &>/dev/null; then
    NOTIFY_BIN="dunstify"
elif command -v notify-send &>/dev/null; then
    NOTIFY_BIN="notify-send"
    notify-send --help 2>&1 | grep -q -- '--replace-id' && NOTIFY_REPLACE=true || NOTIFY_REPLACE=false
else
    echo "battery-notify: need dunstify or notify-send for notifications." >&2
    exit 1
fi

# notify <replace_id> <urgency> <timeout_ms> <icon> <summary> <body>
notify() {
    local rid="$1" urgency="$2" timeout="$3" icon="$4" summary="$5" body="$6"
    if [[ "$NOTIFY_BIN" == "dunstify" ]]; then
        dunstify -r "$rid" -u "$urgency" -t "$timeout" -i "$icon" "$summary" "$body"
    elif [[ "${NOTIFY_REPLACE:-false}" == true ]]; then
        notify-send --replace-id="$rid" -u "$urgency" -t "$timeout" -i "$icon" "$summary" "$body"
    else
        notify-send -u "$urgency" -t "$timeout" -i "$icon" -h "string:x-dunst-stack-tag:battery-notify" "$summary" "$body"
    fi
}

LAST_NOTIFIED=100  # tracks lowest threshold already notified this discharge cycle
LAST_STATUS=$(cat "$BAT_PATH/status" 2>/dev/null)

while true; do
    level=$(cat "$BAT_PATH/capacity" 2>/dev/null) || { sleep "$POLL_INTERVAL"; continue; }
    status=$(cat "$BAT_PATH/status" 2>/dev/null)

    if [[ "$status" != "$LAST_STATUS" && -n "$status" ]]; then
        case "$status" in
            Charging)
                notify "$STATUS_NOTIFY_ID" low "$STATE_TIMEOUT" "battery-good-charging" "Power connected" "Charging (${level}%)"
                ;;
            Discharging)
                notify "$STATUS_NOTIFY_ID" low "$STATE_TIMEOUT" "battery-low" "On battery" "Discharging (${level}%)"
                ;;
            Full)
                notify "$STATUS_NOTIFY_ID" low "$STATE_TIMEOUT" "battery-full-charged" "Battery full" "100%"
                ;;
            "Not charging")
                notify "$STATUS_NOTIFY_ID" low "$STATE_TIMEOUT" "battery" "Power state changed" "Not charging (${level}%)"
                ;;
        esac
        LAST_STATUS="$status"
    fi

    if [[ "$status" == "Discharging" ]]; then
        # Walk thresholds from highest to lowest; notify once per crossing going down
        for threshold in 40 30 20 10; do
            if (( level <= threshold && LAST_NOTIFIED > threshold )); then
                LAST_NOTIFIED=$threshold

                if (( threshold <= 20 )); then
                    urgency="critical"
                    icon="battery-caution"
                    timeout="$CRITICAL_TIMEOUT"
                else
                    urgency="low"
                    icon="battery-low"
                    timeout="$STATE_TIMEOUT"
                fi

                notify "$NOTIFY_ID" "$urgency" "$timeout" "$icon" "Battery ${level}%" "Plug in soon."
                break
            fi
        done
    else
        # Charging or Full — reset so we notify again next discharge cycle
        LAST_NOTIFIED=100
    fi

    sleep "$POLL_INTERVAL"
done
