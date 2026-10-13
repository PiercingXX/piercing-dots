#!/usr/bin/env bash
# Rotate a random wallpaper from ~/.config/sway/wallpaper every INTERVAL seconds.

WALL_DIR="${WALL_DIR:-$HOME/.config/sway/wallpaper}"
INTERVAL="${INTERVAL:-600}"   # 10 minutes

pick() {
    find "$WALL_DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
        | shuf -n1
}

pkill -x swaybg 2>/dev/null

img=$(pick)
[ -n "$img" ] || { echo "No wallpapers in $WALL_DIR" >&2; exit 1; }
swaybg -i "$img" -m fill &
old_pid=$!

while true; do
    sleep "$INTERVAL"
    img=$(pick)
    [ -n "$img" ] || continue
    swaybg -i "$img" -m fill &
    next_pid=$!
    # Let the new one draw before removing the old one (no flash)
    sleep 5
    kill "$old_pid" 2>/dev/null
    old_pid=$next_pid
done
