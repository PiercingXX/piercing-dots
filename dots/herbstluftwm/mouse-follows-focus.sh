#!/usr/bin/env bash
# Warp mouse to center of focused window when focus changes via keyboard.
# Skips warp if mouse is already inside the focused window (i.e. focus followed mouse).

herbstclient --idle 'focus_changed' | while read -r _ winid _; do
    [ -n "$winid" ] || continue

    # Get window geometry (sets X, Y, WIDTH, HEIGHT)
    geom=$(xdotool getwindowgeometry --shell "$winid" 2>/dev/null) || continue
    win_x=$(echo "$geom" | grep '^X=' | cut -d= -f2)
    win_y=$(echo "$geom" | grep '^Y=' | cut -d= -f2)
    win_w=$(echo "$geom" | grep '^WIDTH=' | cut -d= -f2)
    win_h=$(echo "$geom" | grep '^HEIGHT=' | cut -d= -f2)

    # Get current mouse position (sets X, Y)
    mouse=$(xdotool getmouselocation --shell 2>/dev/null) || continue
    mouse_x=$(echo "$mouse" | grep '^X=' | cut -d= -f2)
    mouse_y=$(echo "$mouse" | grep '^Y=' | cut -d= -f2)

    # Only warp if mouse is outside the focused window (keyboard navigation)
    if [ "$mouse_x" -lt "$win_x" ] || [ "$mouse_x" -gt $((win_x + win_w)) ] || \
       [ "$mouse_y" -lt "$win_y" ] || [ "$mouse_y" -gt $((win_y + win_h)) ]; then
        xdotool mousemove --window "$winid" --clearmodifiers 50% 50% 2>/dev/null || true
    fi
done
