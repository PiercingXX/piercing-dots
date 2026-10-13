#!/bin/bash
# GitHub.com/PiercingXX
# Show this month's calendar in a notification.

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

MONTH_TITLE="$(date '+%B %Y')"

if command_exists cal; then
    CAL_BODY="$(cal)"
else
    CAL_BODY="Calendar utility not found"
fi

if command_exists notify-send; then
    notify_replace calendar low 6000 x-office-calendar "$MONTH_TITLE" "$CAL_BODY"
else
    printf '%s\n%s\n' "$MONTH_TITLE" "$CAL_BODY"
fi
