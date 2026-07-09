#!/bin/bash

launch_ulauncher() {
    # If Ulauncher is already running, toggle it exactly once.
    if pgrep -x ulauncher >/dev/null 2>&1; then
        if command -v ulauncher-toggle >/dev/null 2>&1; then
            ulauncher-toggle >/dev/null 2>&1 || true
        fi
        return 0
    fi

    # If not running yet, start it and return without a second toggle.
    if command -v ulauncher >/dev/null 2>&1; then
        ulauncher >/dev/null 2>&1 &
        return 0
    fi

    return 1
}

launch_ulauncher && exit 0

if [ -n "$WAYLAND_DISPLAY" ] && command -v fuzzel >/dev/null 2>&1; then
    exec fuzzel
fi

if command -v rofi >/dev/null 2>&1; then
    exec rofi -show drun
fi

echo "No supported launcher found." >&2
exit 1