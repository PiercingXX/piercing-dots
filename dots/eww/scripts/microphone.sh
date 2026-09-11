#!/bin/bash
# Mic mute state for legacy eww variables.yuck
if command -v pamixer >/dev/null 2>&1; then
  src="$(pactl get-default-source 2>/dev/null || true)"
  if [[ -n "$src" ]]; then
    pamixer --source "$src" --get-mute
  else
    echo false
  fi
elif command -v pactl >/dev/null 2>&1; then
  if pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | grep -q yes; then
    echo true
  else
    echo false
  fi
else
  echo false
fi
