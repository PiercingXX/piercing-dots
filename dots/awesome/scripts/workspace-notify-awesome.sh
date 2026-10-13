#!/bin/bash
# GitHub.com/PiercingXX
# One-shot workspace bubble for awesome; called from rc.lua on tag change.
exec bash "$HOME/.scripts/Control-Scripts/workspace-notify.sh" --wm awesome --once "$@"
