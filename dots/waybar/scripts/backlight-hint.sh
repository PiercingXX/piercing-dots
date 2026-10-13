#!/usr/bin/env bash
# Click hint for the backlight module: yad popup if installed, otherwise a notification.

msg="Scroll your mouse wheel to change the backlight of the monitor."

if command -v yad >/dev/null 2>&1; then
    yad --width=100 --height=100 \
        --center \
        --fixed \
        --title="Backlight" \
        --no-buttons \
        --timeout=10 \
        --timeout-indicator=bottom \
        --text="\n${msg}"
else
    notify-send -u low -t 4000 -i display-brightness-symbolic "Backlight" "$msg"
fi
