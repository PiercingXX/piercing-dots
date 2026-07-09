#!/bin/bash
# GitHub.com/PiercingXX
# One-shot update availability notification.

NOTIFY_ID=99984
STATE_TIMEOUT=2200

if command -v dunstify &>/dev/null; then
    NOTIFY_BIN="dunstify"
elif command -v notify-send &>/dev/null; then
    NOTIFY_BIN="notify-send"
    notify-send --help 2>&1 | grep -q -- '--replace-id' && NOTIFY_REPLACE=true || NOTIFY_REPLACE=false
else
    echo "update-notify: need dunstify or notify-send." >&2
    exit 1
fi

notify() {
    local summary="$1" body="$2" icon="$3" urgency="$4"
    if [[ "$NOTIFY_BIN" == "dunstify" ]]; then
        dunstify -r "$NOTIFY_ID" -u "$urgency" -t "$STATE_TIMEOUT" -i "$icon" "$summary" "$body"
    elif [[ "${NOTIFY_REPLACE:-false}" == true ]]; then
        notify-send --replace-id="$NOTIFY_ID" -u "$urgency" -t "$STATE_TIMEOUT" -i "$icon" "$summary" "$body"
    else
        notify-send -u "$urgency" -t "$STATE_TIMEOUT" -i "$icon" -h "string:x-dunst-stack-tag:update-notify" "$summary" "$body"
    fi
}

count_updates() {
    if command -v checkupdates &>/dev/null; then
        checkupdates 2>/dev/null | wc -l
        return
    fi

    if command -v paru &>/dev/null; then
        paru -Qua 2>/dev/null | wc -l
        return
    fi

    if command -v pacman &>/dev/null; then
        pacman -Qu 2>/dev/null | wc -l
        return
    fi

    if command -v apt &>/dev/null; then
        apt list --upgradable 2>/dev/null | sed '1d' | wc -l
        return
    fi

    if command -v dnf &>/dev/null; then
        dnf -q check-update 2>/dev/null | awk 'NF{c++} END{print c+0}'
        return
    fi

    if command -v xbps-install &>/dev/null; then
        xbps-install -Mun 2>/dev/null | wc -l
        return
    fi

    echo 0
}

count=$(count_updates)

if [[ "$count" =~ ^[0-9]+$ ]] && (( count > 0 )); then
    notify "Updates available" "$count packages can be updated" "software-update-available" "low"
fi
