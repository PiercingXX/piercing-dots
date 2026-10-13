#!/usr/bin/env bash
# Enable/disable the laptop panel with the lid (bind to `bindswitch lid:toggle`).
# OUTPUT defaults to the first internal panel sway reports (eDP/LVDS).

OUTPUT="${1:-$(swaymsg -t get_outputs -r 2>/dev/null | jq -r '[.[] | select(.name | test("^(eDP|LVDS)"))][0].name // "eDP-1"')}"

lid_state=""
for f in /proc/acpi/button/lid/*/state; do
    [ -r "$f" ] && lid_state=$(cat "$f") && break
done
[ -n "$lid_state" ] || exit 0

if grep -q open <<<"$lid_state"; then
    swaymsg output "$OUTPUT" enable
else
    swaymsg output "$OUTPUT" disable
fi
