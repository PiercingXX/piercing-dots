#!/bin/bash

set -e

mode="${1:-region}"
NOTIFY_ID=99983
QUICK_TIMEOUT=1100

if command -v dunstify >/dev/null 2>&1; then
    NOTIFY_BIN="dunstify"
elif command -v notify-send >/dev/null 2>&1; then
    NOTIFY_BIN="notify-send"
    notify-send --help 2>&1 | grep -q -- '--replace-id' && NOTIFY_REPLACE=true || NOTIFY_REPLACE=false
else
    NOTIFY_BIN=""
fi

notify_screenshot() {
    local summary="$1" body="$2" icon="$3" urgency="$4" timeout="$5"
    [ -z "$NOTIFY_BIN" ] && return 0
    if [[ "$NOTIFY_BIN" == "dunstify" ]]; then
        dunstify -r "$NOTIFY_ID" -u "$urgency" -t "$timeout" -i "$icon" "$summary" "$body"
    elif [[ "${NOTIFY_REPLACE:-false}" == true ]]; then
        notify-send --replace-id="$NOTIFY_ID" -u "$urgency" -t "$timeout" -i "$icon" "$summary" "$body"
    else
        notify-send -u "$urgency" -t "$timeout" -i "$icon" -h "string:x-dunst-stack-tag:screenshot" "$summary" "$body"
    fi
}

if [ -n "$WAYLAND_DISPLAY" ]; then
    if command -v hyprshot >/dev/null 2>&1; then
        screenshot_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
        mkdir -p "$screenshot_dir"
        case "$mode" in
            region|select|selecttime)
                output=$(hyprshot -m region -o "$screenshot_dir" 2>&1)
                ;;
            window)
                output=$(hyprshot -m window -o "$screenshot_dir" 2>&1)
                ;;
            full|fulltime)
                output=$(hyprshot -m output -o "$screenshot_dir" 2>&1)
                ;;
        esac
        shot_file=$(echo "$output" | grep -Eo '/[^[:space:]]+\.(png|jpg|jpeg|webp)' | tail -1)
        if [ -n "$shot_file" ]; then
            notify_screenshot "Screenshot saved" "$shot_file" "camera-photo" "low" "$QUICK_TIMEOUT"
        else
            notify_screenshot "Screenshot captured" "$mode" "camera-photo" "low" "$QUICK_TIMEOUT"
        fi
        exit 0
    fi

    if command -v grim >/dev/null 2>&1; then
        screenshot_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
        mkdir -p "$screenshot_dir"
        screenshot_file="$screenshot_dir/$(date +%F-%H%M%S).png"

        case "$mode" in
            select|region)
                geometry="$(slurp)"
                [ -n "$geometry" ] || exit 0
                grim -g "$geometry" "$screenshot_file"
                ;;
            window)
                geometry="$(swaymsg -t get_tree | jq -r 'recurse(.nodes[]?, .floating_nodes[]?) | select(.focused) | .rect | "\(.x),\(.y) \(.width)x\(.height)"' | head -n 1)"
                [ -n "$geometry" ] || exit 0
                grim -g "$geometry" "$screenshot_file"
                ;;
            fulltime)
                sleep 5
                grim "$screenshot_file"
                ;;
            selecttime)
                sleep 5
                geometry="$(slurp)"
                [ -n "$geometry" ] || exit 0
                grim -g "$geometry" "$screenshot_file"
                ;;
            *)
                grim "$screenshot_file"
                ;;
        esac

        if command -v wl-copy >/dev/null 2>&1; then
            wl-copy < "$screenshot_file" || true
        fi

        notify_screenshot "Screenshot saved" "$screenshot_file" "camera-photo" "low" "$QUICK_TIMEOUT"

        exit 0
    fi
fi

if ! command -v flameshot >/dev/null 2>&1; then
    echo "flameshot is required for X11 screenshots." >&2
    exit 1
fi

case "$mode" in
    full)
        flameshot full -c
        notify_screenshot "Screenshot captured" "Copied to clipboard" "camera-photo" "low" "$QUICK_TIMEOUT"
        exit 0
        ;;
    fulltime)
        sleep 5
        flameshot full -c
        notify_screenshot "Screenshot captured" "Copied to clipboard" "camera-photo" "low" "$QUICK_TIMEOUT"
        exit 0
        ;;
    selecttime)
        sleep 5
        flameshot gui --clipboard
        notify_screenshot "Screenshot captured" "Copied to clipboard" "camera-photo" "low" "$QUICK_TIMEOUT"
        exit 0
        ;;
    *)
        flameshot gui --clipboard
        notify_screenshot "Screenshot captured" "Copied to clipboard" "camera-photo" "low" "$QUICK_TIMEOUT"
        exit 0
        ;;
esac