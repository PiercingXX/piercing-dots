#!/usr/bin/env bash
# Usage: workspace_action.sh <workspace|movetoworkspace|movetoworkspacesilent> <1-10>
# Targets workspace N within the current group of ten.
# Hyprland 0.55+ takes Lua dispatchers, so map the old dispatcher names here.
target=$(((($(hyprctl activeworkspace -j | jq -r .id) - 1) / 10) * 10 + $2))

case "$1" in
    workspace)             hyprctl dispatch "hl.dsp.focus({ workspace = '$target' })" ;;
    movetoworkspace)       hyprctl dispatch "hl.dsp.window.move({ workspace = '$target' })" ;;
    movetoworkspacesilent) hyprctl dispatch "hl.dsp.window.move({ workspace = '$target', follow = false })" ;;
    *) echo "workspace_action.sh: unknown action '$1'" >&2; exit 1 ;;
esac
