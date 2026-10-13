#!/bin/bash
# GitHub.com/PiercingXX
# Bluetooth Manager: bluetui (preferred), bluetuith, or bluetoothctl.

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
detect_distro

pick_tui() {
    local t
    for t in bluetui bluetuith bluetoothctl; do
        command_exists "$t" && { echo "$t"; return 0; }
    done
    return 1
}

install_tui() {
    case "$DISTRO" in
        arch)
            # bluetui is in extra; bluetuith is AUR-only
            pkg_install bluetui && return 0
            local helper
            helper=$(aur_helper)
            [ -n "$helper" ] && "$helper" -S --needed bluetuith && return 0
            ;;
        artix)  pkg_install bluez-utils ;;
        void)   pkg_install bluetuith || pkg_install bluez ;;
        debian) pkg_install bluez ;;
        fedora) pkg_install bluez ;;
        suse)   pkg_install bluez ;;
        alpine) pkg_install bluez ;;
    esac
}

tui=$(pick_tui)
if [ -z "$tui" ]; then
    warn "No Bluetooth TUI found (bluetui, bluetuith or bluetoothctl)."
    if confirm "Install one now?"; then
        install_tui
        tui=$(pick_tui)
    fi
    [ -n "$tui" ] || die "No Bluetooth tool available. Install bluetui (Arch: extra) or bluez."
fi

# Service name differs by init: bluetooth (systemd/openrc), bluetoothd (runit)
bt_service=bluetooth
[ "$INIT" = runit ] && bt_service=bluetoothd
if ! svc_is_active "$bt_service" && ! pgrep -x bluetoothd >/dev/null 2>&1; then
    warn "The Bluetooth service ($bt_service) is not running."
    if confirm "Start and enable it now?"; then
        svc_enable_now "$bt_service" || warn "Could not start $bt_service."
    fi
fi

# Soft-blocked adapters show up as "no controller" in every TUI
if command_exists rfkill && rfkill list bluetooth 2>/dev/null | grep -q 'Soft blocked: yes'; then
    warn "Bluetooth is soft-blocked (rfkill)."
    if confirm "Unblock it?"; then
        rfkill unblock bluetooth 2>/dev/null || sudo rfkill unblock bluetooth
    fi
fi

clear
if [ "$tui" = bluetoothctl ]; then
    say "Opening bluetoothctl (try: power on, scan on, devices, pair <MAC>, connect <MAC>, exit)."
fi
"$tui"
