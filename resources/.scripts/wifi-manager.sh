#!/usr/bin/env bash
# GitHub.com/PiercingXX

# Simple WiFi Manager using nmtui

# Ensure nmtui is available
if ! command -v nmtui &>/dev/null; then
    echo "nmtui is not installed. Please install NetworkManager to use this WiFi manager."
    exit 1
fi

# Launch nmtui for WiFi management
sudo nmtui

# After exiting nmtui, return to the settings menu if available
SCRIPT_DIR="$(dirname "$0")"
SETTINGS_MENU="$SCRIPT_DIR/settings-menu.sh"
if [ -x "$SETTINGS_MENU" ]; then
    "$SETTINGS_MENU"
else
    echo "Settings menu not found at $SETTINGS_MENU."
fi
