#!/bin/bash
# Deprecated: color temperature is owned by ~/.config/hypr/hyprsunset.conf.
# Older configs started this script AND hyprsunset's native profiles (double apply).
# Keep starting the daemon only; do not re-apply temperatures here.
set -u
if ! pgrep -x hyprsunset >/dev/null 2>&1; then
    command -v hyprsunset >/dev/null 2>&1 && hyprsunset >/tmp/hyprsunset.log 2>&1 &
fi
exit 0
