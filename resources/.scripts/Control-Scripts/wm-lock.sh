#!/bin/bash
# GitHub.com/PiercingXX
# Lock the screen with whatever fits the session.
# When an idle daemon owns locking (hypridle), go through loginctl so its
# lock_cmd runs and before/after-sleep hooks stay consistent.

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

if is_wayland; then
    if pgrep -x hypridle >/dev/null 2>&1 && command_exists loginctl; then
        exec loginctl lock-session
    fi
    if command_exists hyprlock; then
        exec hyprlock
    fi
    if command_exists swaylock; then
        exec swaylock -f
    fi
    # X11 lockers can't lock a Wayland session; say so instead of failing silently
    notify_replace lock critical 5000 dialog-error "Screen lock" "Install hyprlock or swaylock."
    echo "No Wayland lock command found (hyprlock/swaylock)." >&2
    exit 1
fi

if command_exists betterlockscreen; then
    exec betterlockscreen -l
fi

if command_exists i3lock; then
    exec i3lock -c 000000
fi

notify_replace lock critical 5000 dialog-error "Screen lock" "Install betterlockscreen or i3lock."
echo "No supported lock command found." >&2
exit 1
