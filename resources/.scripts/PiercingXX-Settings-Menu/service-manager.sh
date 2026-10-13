#!/bin/bash
# GitHub.com/PiercingXX
# Service Manager: start/stop/restart/enable/disable services and read their logs.
# systemd (system + user units); runit/OpenRC/dinit get start/stop/status/enable.

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
detect_distro

command_exists gum || die "gum is required for this menu."

pager() { gum pager; }

# ---------------------------------------------------------------------------
# systemd
# ---------------------------------------------------------------------------
systemd_unit_actions() {
    local scope="$1" unit="$2" action
    local -a sc=(systemctl)
    local -a jc=(journalctl)
    if [ "$scope" = user ]; then
        sc=(systemctl --user); jc=(journalctl --user)
    else
        sc=(sudo systemctl); jc=(sudo journalctl)
    fi
    while true; do
        clear
        systemctl ${scope:+--$scope} --no-pager status "$unit" 2>&1 | head -n 12
        echo
        action=$(gum choose --header "$unit" "Status" "Logs (last 300)" "Restart" "Start" "Stop" "Enable" "Disable" "Back") || return 0
        case "$action" in
            "Status")          systemctl ${scope:+--$scope} --no-pager status "$unit" 2>&1 | pager; continue ;;
            "Logs (last 300)") "${jc[@]}" -u "$unit" -n 300 --no-pager 2>&1 | pager; continue ;;
            "Restart")         "${sc[@]}" restart "$unit" ;;
            "Start")           "${sc[@]}" start "$unit" ;;
            "Stop")            gum confirm "Stop $unit?" && "${sc[@]}" stop "$unit" ;;
            "Enable")          "${sc[@]}" enable "$unit" ;;
            "Disable")         gum confirm "Disable $unit?" --default=false && "${sc[@]}" disable "$unit" ;;
            *) return 0 ;;
        esac
        sleep 0.5
    done
}

systemd_menu() {
    local choice scope unit
    while true; do
        clear
        choice=$(gum choose --header "Services (systemd)" \
            "System services" "User services" "Failed units" "Back") || return 0
        case "$choice" in
            "System services") scope="" ;;
            "User services")   scope="user" ;;
            "Failed units")
                { echo "System:"; systemctl --failed --no-pager --no-legend; echo; echo "User:"; systemctl --user --failed --no-pager --no-legend; } | pager
                if gum confirm "Clear the failed state (reset-failed)?" --default=false; then
                    sudo systemctl reset-failed
                    systemctl --user reset-failed
                fi
                continue ;;
            *) return 0 ;;
        esac
        unit=$(systemctl ${scope:+--$scope} list-units --type=service --all --no-legend --plain --no-pager 2>/dev/null \
            | awk '{printf "%-50s %-8s %s\n", $1, $3, $4}' \
            | gum filter --placeholder "search ${scope:-system} services" | awk '{print $1}') || continue
        [ -n "$unit" ] && systemd_unit_actions "$scope" "$unit"
    done
}

# ---------------------------------------------------------------------------
# runit / OpenRC / dinit (Artix, Void, Alpine)
# ---------------------------------------------------------------------------
list_other_services() {
    case "$INIT" in
        runit)  ls /etc/sv /etc/runit/sv 2>/dev/null | grep -v ':$' | sort -u ;;
        openrc) ls /etc/init.d 2>/dev/null ;;
        dinit)  ls /etc/dinit.d 2>/dev/null ;;
        s6)     ls /etc/s6/sv 2>/dev/null ;;
    esac
}

other_menu() {
    local svc action
    while true; do
        clear
        svc=$(list_other_services | gum filter --placeholder "search $INIT services") || return 0
        [ -n "$svc" ] || return 0
        while true; do
            clear
            if svc_is_active "$svc"; then echo "$svc: running"; else echo "$svc: stopped"; fi
            echo
            action=$(gum choose --header "$svc ($INIT)" "Start" "Stop" "Restart" "Enable at boot" "Back") || break
            case "$action" in
                "Start")          svc_start "$svc" ;;
                "Stop")           gum confirm "Stop $svc?" && svc_stop "$svc" ;;
                "Restart")        svc_stop "$svc"; svc_start "$svc" ;;
                "Enable at boot") svc_enable_now "$svc" ;;
                *) break ;;
            esac
            sleep 0.5
        done
    done
}

case "$INIT" in
    systemd) systemd_menu ;;
    runit|openrc|dinit|s6) other_menu ;;
    *) die "Unknown init system; can't manage services from here." ;;
esac
