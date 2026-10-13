#!/bin/bash
# GitHub.com/PiercingXX
# Toggle the touchpad on/off.
#   Hyprland: per-device `enabled` keyword   Sway: input type:touchpad events
#   X11:      xinput

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/piercingxx-touchpad-disabled"

say_state() {
    notify_replace touchpad low 1500 input-touchpad "Touchpad $1"
}

case "$(detect_wm)" in
    hyprland)
        mapfile -t pads < <(hyprctl devices -j 2>/dev/null | jq -r '.mice[].name' | grep -i -E 'touchpad|trackpad|synaptics|elan|glidepoint')
        [ ${#pads[@]} -gt 0 ] || { say_state "not found"; exit 0; }
        if [ -f "$STATE_FILE" ]; then new=true; rm -f "$STATE_FILE"; else new=false; touch "$STATE_FILE"; fi
        for pad in "${pads[@]}"; do
            # Lua config (0.56+) first, classic keyword for older Hyprland
            hyprctl eval "hl.device({ name = \"$pad\", enabled = $new })" >/dev/null 2>&1 \
                || hyprctl keyword "device[$pad]:enabled" "$new" >/dev/null
        done
        [ "$new" = true ] && say_state enabled || say_state disabled
        exit 0
        ;;
    sway)
        swaymsg input type:touchpad events toggle enabled disabled >/dev/null
        if swaymsg -t get_inputs -r | jq -e '[.[] | select(.type=="touchpad") | .libinput.send_events] | any(. == "disabled")' >/dev/null; then
            say_state disabled
        else
            say_state enabled
        fi
        exit 0
        ;;
esac

if ! command_exists xinput; then
    say_state "toggle unsupported here"
    exit 0
fi

# xinput matches device names literally, so look the touchpad up by name
touchpad_name="$(xinput list --name-only | grep -i -E 'touchpad|trackpad|synaptics|glidepoint' | head -n 1)"
[ -n "$touchpad_name" ] || { say_state "not found"; exit 0; }
touchpad_id="$(xinput list --id-only "$touchpad_name" 2>/dev/null | head -n 1)"
[ -n "$touchpad_id" ] || exit 0

if xinput list-props "$touchpad_id" | grep -Eq 'Device Enabled \([0-9]+\):[[:space:]]*1'; then
    xinput disable "$touchpad_id"
    say_state disabled
else
    xinput enable "$touchpad_id"
    say_state enabled
fi
