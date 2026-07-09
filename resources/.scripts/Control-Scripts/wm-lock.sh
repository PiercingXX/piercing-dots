#!/bin/bash

if [ -n "$WAYLAND_DISPLAY" ]; then
    if command -v hyprlock >/dev/null 2>&1; then
        exec hyprlock
    fi

    if command -v swaylock >/dev/null 2>&1; then
        exec swaylock
    fi
fi

if command -v betterlockscreen >/dev/null 2>&1; then
    exec betterlockscreen -l
fi

if command -v i3lock >/dev/null 2>&1; then
    exec i3lock -c 000000
fi

echo "No supported lock command found." >&2
exit 1