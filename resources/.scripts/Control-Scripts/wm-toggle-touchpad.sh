#!/bin/bash

set -e

if ! command -v xinput >/dev/null 2>&1; then
    exit 0
fi

touchpad_id="$(xinput list --id-only 'pointer:.*touchpad' 2>/dev/null | head -n 1)"

if [ -z "$touchpad_id" ]; then
    touchpad_name="$(xinput list --name-only | grep -i touchpad | head -n 1)"
    [ -n "$touchpad_name" ] && touchpad_id="$(xinput list --id-only "$touchpad_name" 2>/dev/null | head -n 1)"
fi

[ -n "$touchpad_id" ] || exit 0

if xinput list-props "$touchpad_id" | grep -Eq 'Device Enabled \([0-9]+\):[[:space:]]*1'; then
    xinput disable "$touchpad_id"
    command -v notify-send >/dev/null 2>&1 && notify-send "Touchpad disabled"
else
    xinput enable "$touchpad_id"
    command -v notify-send >/dev/null 2>&1 && notify-send "Touchpad enabled"
fi