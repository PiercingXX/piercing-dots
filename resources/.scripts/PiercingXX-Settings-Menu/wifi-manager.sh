#!/bin/bash
# GitHub.com/PiercingXX
# WiFi Manager: nmtui for NetworkManager, impala/iwctl for iwd.
# Runs unprivileged; NetworkManager/iwd authorize through polkit.

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
detect_distro

nm_running() {
    command_exists nmcli && nmcli -t -f RUNNING general 2>/dev/null | grep -q running
}

iwd_running() {
    svc_is_active iwd || pgrep -x iwd >/dev/null 2>&1
}

clear
if nm_running; then
    if command_exists nmtui; then
        nmtui
    else
        err "NetworkManager is running but nmtui is missing (install network-manager / networkmanager-tui)."
        exit 1
    fi
elif iwd_running; then
    if command_exists impala; then
        impala
    elif command_exists iwctl; then
        say "iwd is running. Opening iwctl (try: station list, station <dev> scan, station <dev> connect <SSID>, exit)."
        iwctl
    else
        err "iwd is running but neither impala nor iwctl is installed."
        exit 1
    fi
elif command_exists nmtui; then
    warn "NetworkManager is installed but not running."
    if confirm "Start and enable NetworkManager now?"; then
        svc_enable_now NetworkManager || die "Could not start NetworkManager."
        sleep 1
        nmtui
    fi
else
    err "No network manager found. Install NetworkManager (nmtui) or iwd (iwctl/impala)."
    exit 1
fi
