#!/bin/bash

set -euo pipefail

start_if_missing() {
    local process_name="$1"
    local command_name="$2"

    if pgrep -x "$process_name" >/dev/null 2>&1; then
        return 0
    fi

    if command -v "$command_name" >/dev/null 2>&1; then
        "$command_name" >/dev/null 2>&1 &
    fi
}

repair_flatpak_pulse_dir() {
    local runtime_dir app_runtime pulse_path

    runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    app_runtime="$runtime_dir/.flatpak/net.waterfox.waterfox/xdg-run"
    pulse_path="$app_runtime/pulse"

    [[ -d "$app_runtime" ]] || return 0

    if [[ -d "$pulse_path" && ! -L "$pulse_path" ]]; then
        rm -rf "$pulse_path"
    fi
}

start_if_missing pipewire pipewire
start_if_missing wireplumber wireplumber
start_if_missing pipewire-pulse pipewire-pulse

repair_flatpak_pulse_dir