#!/bin/bash
# Compatibility wrapper — quick_settings.yuck historically called nightlight.sh
exec "$(dirname "$0")/nightlight" "$@"
