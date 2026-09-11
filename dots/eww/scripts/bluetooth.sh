#!/bin/bash
# Bluetooth powered-on state (not merely bluetoothd present).

if ! command -v bluetoothctl >/dev/null 2>&1; then
  echo false
  exit 0
fi

if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
  echo true
else
  echo false
fi
