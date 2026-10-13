#!/bin/bash
# GitHub.com/PiercingXX
# Toggle microphone mute and show the shared on-screen bubble.
# Bound to XF86AudioMicMute in the WM configs.

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

if command_exists wpctl; then
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    muted=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED && echo yes || echo no)
elif command_exists pactl; then
    pactl set-source-mute @DEFAULT_SOURCE@ toggle
    muted=$(pactl get-source-mute @DEFAULT_SOURCE@ | grep -q yes && echo yes || echo no)
else
    notify_replace mic normal 3000 dialog-error "Microphone" "Install wireplumber (wpctl) or pulseaudio-utils (pactl)."
    exit 1
fi

if [ "$muted" = yes ]; then
    osd microphone-sensitivity-muted "Microphone muted" 0
else
    osd audio-input-microphone "Microphone on" 100
fi
