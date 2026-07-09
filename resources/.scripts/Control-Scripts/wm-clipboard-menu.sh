#!/bin/bash

set -e

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/piercingxx"
history_file="$cache_dir/clipboard-history.txt"

if [ -n "$WAYLAND_DISPLAY" ] && command -v cliphist >/dev/null 2>&1 && command -v fuzzel >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1; then
    pkill fuzzel >/dev/null 2>&1 || true
    cliphist list | fuzzel --match-mode fzf --dmenu | cliphist decode | wl-copy
    exit 0
fi

[ -f "$history_file" ] || exit 0

if command -v rofi >/dev/null 2>&1; then
    selection="$(cat "$history_file" | rofi -dmenu -i -p Clipboard)"
elif command -v fuzzel >/dev/null 2>&1; then
    selection="$(cat "$history_file" | fuzzel --dmenu)"
else
    exit 1
fi

[ -n "$selection" ] || exit 0

if command -v xclip >/dev/null 2>&1; then
    printf '%s' "$selection" | xclip -selection clipboard
elif command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$selection" | wl-copy
fi