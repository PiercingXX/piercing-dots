#!/bin/bash
# GitHub.com/PiercingXX
# Output volume keys with an on-screen bubble.
# Usage: volume.sh inc|dec|mute|get
# wpctl (PipeWire/WirePlumber) first, pactl as fallback; capped at 100%.
# Hotkey script: never installs packages, just tells you what's missing.

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

STEP=5

case "${1:-}" in
    inc|dec|mute|get) ;;
    *) printf 'Usage: %s [inc|dec|mute|get]\n' "$(basename "$0")" >&2; exit 1 ;;
esac

if command_exists wpctl; then
    BACKEND=wpctl
elif command_exists pactl; then
    BACKEND=pactl
else
    notify_replace volume normal 3000 dialog-error "Volume" "Install wireplumber (wpctl) or pulseaudio-utils (pactl)."
    exit 1
fi

# Prints "<percent> <yes|no>" (muted)
get_state() {
    if [ "$BACKEND" = wpctl ]; then
        wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null \
            | awk '{printf "%d %s\n", $2 * 100 + 0.5, (/MUTED/ ? "yes" : "no")}'
    else
        local vol mute
        vol=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oE '[0-9]+%' | head -1 | tr -d '%')
        mute=$(pactl get-sink-mute @DEFAULT_SINK@ | awk '{print $2}')
        echo "${vol:-0} ${mute:-no}"
    fi
}

case "$1" in
    inc)
        if [ "$BACKEND" = wpctl ]; then
            wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
            wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "${STEP}%+"
        else
            pactl set-sink-mute @DEFAULT_SINK@ 0
            read -r cur _ < <(get_state)
            if (( cur + STEP >= 100 )); then
                pactl set-sink-volume @DEFAULT_SINK@ 100%
            else
                pactl set-sink-volume @DEFAULT_SINK@ "+${STEP}%"
            fi
        fi ;;
    dec)
        if [ "$BACKEND" = wpctl ]; then
            wpctl set-volume @DEFAULT_AUDIO_SINK@ "${STEP}%-"
        else
            pactl set-sink-volume @DEFAULT_SINK@ "-${STEP}%"
        fi ;;
    mute)
        if [ "$BACKEND" = wpctl ]; then
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        else
            pactl set-sink-mute @DEFAULT_SINK@ toggle
        fi ;;
esac

read -r volume muted < <(get_state)
volume=${volume:-0}

if [ "$1" = get ]; then
    echo "$volume $muted"
    exit 0
fi

if [ "$muted" = yes ]; then
    osd audio-volume-muted "Volume muted" 0
    exit 0
fi

if (( volume == 0 )); then
    icon="audio-volume-muted"
elif (( volume < 30 )); then
    icon="audio-volume-low"
elif (( volume < 70 )); then
    icon="audio-volume-medium"
else
    icon="audio-volume-high"
fi

osd "$icon" "Volume ${volume}%" "$volume"
