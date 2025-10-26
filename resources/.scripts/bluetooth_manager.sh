#!/usr/bin/env bash
# GitHub.com/PiercingXX

# Bluetooth Manager using bluetuith

# Ensure bluetuith is installed
if ! command -v bluetuith &>/dev/null; then
    if command -v paru &>/dev/null; then
        echo "bluetuith not found. Installing bluetuith with paru..."
        paru --noconfirm -S bluetuith
    fi
fi
if ! command -v bluetuith &>/dev/null; then
    echo "bluetuith is not installed and could not be installed automatically. Please install bluetuith."
    exit 1
fi

# Launch bluetuith
bluetuith

# After exiting bluetuith, return to the settings menu
SCRIPT_DIR="$(dirname "$0")"
SETTINGS_MENU="$SCRIPT_DIR/settings-menu.sh"
if [ -x "$SETTINGS_MENU" ]; then
    "$SETTINGS_MENU"
else
    echo "Settings menu not found at $SETTINGS_MENU."
fi