#!/bin/bash
# GitHub.com/PiercingXX
# Waybar custom module: pending updates as JSON (text/tooltip/class).
#   "custom/updates": { "exec": "~/.config/waybar/scripts/check_updates.sh",
#                       "return-type": "json", "interval": 1800 }
counter="$HOME/.scripts/Control-Scripts/update-count.sh"
if [ -x "$counter" ]; then
    exec "$counter" --json
fi
echo '{"text":"0","tooltip":"update-count.sh not installed","class":"none"}'
