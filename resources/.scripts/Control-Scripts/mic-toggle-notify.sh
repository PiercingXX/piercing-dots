#!/bin/bash
# GitHub.com/PiercingXX
# Toggle microphone mute and show notification.

NOTIFY_ID=99982
QUICK_TIMEOUT=1100

if ! command -v pactl &>/dev/null; then
    echo "mic-toggle-notify: pactl not found." >&2
    exit 1
fi

if command -v dunstify &>/dev/null; then
    NOTIFY_BIN="dunstify"
elif command -v notify-send &>/dev/null; then
    NOTIFY_BIN="notify-send"
    notify-send --help 2>&1 | grep -q -- '--replace-id' && NOTIFY_REPLACE=true || NOTIFY_REPLACE=false
else
    echo "mic-toggle-notify: need dunstify or notify-send." >&2
    exit 1
fi

notify() {
    local summary="$1" body="$2" icon="$3" urgency="$4"
    if [[ "$NOTIFY_BIN" == "dunstify" ]]; then
        dunstify -r "$NOTIFY_ID" -u "$urgency" -t "$QUICK_TIMEOUT" -i "$icon" "$summary" "$body"
    elif [[ "${NOTIFY_REPLACE:-false}" == true ]]; then
        notify-send --replace-id="$NOTIFY_ID" -u "$urgency" -t "$QUICK_TIMEOUT" -i "$icon" "$summary" "$body"
    else
        notify-send -u "$urgency" -t "$QUICK_TIMEOUT" -i "$icon" -h "string:x-dunst-stack-tag:mic-toggle" "$summary" "$body"
    fi
}

pactl set-source-mute @DEFAULT_SOURCE@ toggle

if pactl get-source-mute @DEFAULT_SOURCE@ | grep -q 'yes'; then
    notify "Microphone muted" "Input disabled" "microphone-sensitivity-muted" "low"
else
    notify "Microphone unmuted" "Input enabled" "audio-input-microphone" "low"
fi
