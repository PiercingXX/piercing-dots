#!/bin/bash
# GitHub.com/PiercingXX
# Log Viewer: journal errors, kernel, desktop and package-manager logs.

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
detect_distro

command_exists gum || die "gum is required for this menu."

pager() { gum pager; }

hyprland_log() {
    local f=""
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -f "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log" ]; then
        f="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log"
    elif [ -f "$HOME/.cache/hyprland/hyprland.log" ]; then
        f="$HOME/.cache/hyprland/hyprland.log"
    fi
    echo "$f"
}

package_log() {
    case "$PKG" in
        pacman) tail -n 400 /var/log/pacman.log ;;
        apt)    { zcat -f /var/log/apt/history.log* 2>/dev/null; } | tail -n 400 ;;
        dnf)    dnf history list 2>/dev/null | head -n 100 ;;
        xbps)   echo "xbps keeps no transaction log; recent packages:"; xbps-query -m 2>/dev/null | tail -n 100 ;;
        zypper) sudo tail -n 400 /var/log/zypp/history 2>/dev/null ;;
        apk)    echo "apk keeps no transaction log; installed world:"; cat /etc/apk/world ;;
    esac
}

system_log() {
    # Non-systemd syslog locations (Void socklog, Alpine/OpenRC syslog)
    local f
    for f in /var/log/socklog/everything/current /var/log/messages /var/log/syslog /var/log/everything.log; do
        [ -r "$f" ] && { tail -n 500 "$f"; return; }
        [ -e "$f" ] && { sudo tail -n 500 "$f"; return; }
    done
    echo "No system log found."
}

options=()
if [ "$INIT" = systemd ]; then
    options+=("Errors this boot" "Warnings this boot" "Previous boot errors" "Follow journal (Ctrl-C to stop)" "User session journal")
else
    options+=("System log")
fi
options+=("Kernel messages")
[ -n "$(hyprland_log)" ] && options+=("Hyprland log")
[ -f "$HOME/.local/share/xorg/Xorg.0.log" ] || [ -f /var/log/Xorg.0.log ] && options+=("Xorg log")
options+=("Package manager history" "Back")

while true; do
    clear
    choice=$(printf '%s\n' "${options[@]}" | gum choose --header "Logs") || exit 0
    case "$choice" in
        "Errors this boot")     journalctl -b -p err..alert --no-pager 2>&1 | pager ;;
        "Warnings this boot")   journalctl -b -p warning --no-pager 2>&1 | pager ;;
        "Previous boot errors") journalctl -b -1 -p err..alert --no-pager 2>&1 | pager ;;
        "Follow journal (Ctrl-C to stop)")
            trap ':' INT
            journalctl -f
            trap - INT ;;
        "User session journal") journalctl --user -b --no-pager -n 1000 2>&1 | pager ;;
        "System log")           system_log | pager ;;
        "Kernel messages")
            if [ "$INIT" = systemd ]; then
                journalctl -k -b -p warning --no-pager 2>&1 | pager
            else
                { dmesg --level=err,warn 2>/dev/null || sudo dmesg --level=err,warn; } | pager
            fi ;;
        "Hyprland log")         tail -n 1000 "$(hyprland_log)" | pager ;;
        "Xorg log")
            if [ -f "$HOME/.local/share/xorg/Xorg.0.log" ]; then
                grep -E '\((EE|WW)\)' "$HOME/.local/share/xorg/Xorg.0.log" | pager
            else
                grep -E '\((EE|WW)\)' /var/log/Xorg.0.log | pager
            fi ;;
        "Package manager history") package_log 2>&1 | pager ;;
        *) exit 0 ;;
    esac
done
