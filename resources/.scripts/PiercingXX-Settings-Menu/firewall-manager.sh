#!/bin/bash
# GitHub.com/PiercingXX
# Firewall Manager: ufw (preferred, linux-mod enables it) or firewalld.

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
detect_distro

command_exists gum || die "gum is required for this menu."

# name|ports (ufw syntax, space separated)
PRESETS=(
    "SSH|22/tcp"
    "KDE Connect / GSConnect|1714:1764/tcp 1714:1764/udp"
    "LocalSend|53317/tcp 53317/udp"
    "Syncthing|22000/tcp 22000/udp 21027/udp"
)

pager() {
    if command_exists gum; then gum pager; else less -R; fi
}

# ---------------------------------------------------------------------------
# ufw
# ---------------------------------------------------------------------------
ufw_menu() {
    local action
    while true; do
        clear
        sudo ufw status | head -n 1
        action=$(gum choose --header "Firewall (ufw)" \
            "Status (verbose)" "Enable" "Disable" "Allow a preset" "Allow a port" \
            "Deny a port" "Delete a rule" "Back") || return 0
        case "$action" in
            "Status (verbose)") sudo ufw status verbose | pager; continue ;;
            "Enable")
                # Make sure SSH can't be locked out on a remote box
                sudo ufw default deny incoming
                sudo ufw default allow outgoing
                if [ -n "${SSH_CONNECTION:-}" ]; then
                    sudo ufw allow 22/tcp
                fi
                sudo ufw --force enable
                svc_enable_now ufw >/dev/null 2>&1 || true ;;
            "Disable")
                if [ -n "${SSH_CONNECTION:-}" ] || gum confirm "Disable the firewall?" --default=false; then
                    sudo ufw disable
                fi ;;
            "Allow a preset")
                local names=() row name ports p
                for row in "${PRESETS[@]}"; do names+=("${row%%|*}"); done
                name=$(printf '%s\n' "${names[@]}" | gum choose --header "Allow which preset?") || continue
                for row in "${PRESETS[@]}"; do
                    [ "${row%%|*}" = "$name" ] || continue
                    ports="${row#*|}"
                    for p in $ports; do
                        sudo ufw allow "$p" comment "$name"
                    done
                done ;;
            "Allow a port"|"Deny a port")
                local port verb=allow
                [ "$action" = "Deny a port" ] && verb=deny
                port=$(gum input --placeholder "port or range, e.g. 8080/tcp or 6000:6010/udp") || continue
                [[ "$port" =~ ^[0-9]+(:[0-9]+)?(/(tcp|udp))?$ ]] || { err "Not a valid port: $port"; pause; continue; }
                sudo ufw "$verb" "$port" ;;
            "Delete a rule")
                local rule num
                rule=$(sudo ufw status numbered | grep -E '^\[ *[0-9]+\]' | gum choose --header "Delete which rule?") || continue
                [ -n "$rule" ] || continue
                num=$(printf '%s' "$rule" | sed -E 's/^\[ *([0-9]+)\].*/\1/')
                gum confirm "Delete: $rule ?" --default=false && sudo ufw --force delete "$num" ;;
            *) return 0 ;;
        esac
        pause
    done
}

# ---------------------------------------------------------------------------
# firewalld
# ---------------------------------------------------------------------------
firewalld_menu() {
    local action
    while true; do
        clear
        echo "firewalld: $(sudo firewall-cmd --state 2>&1)  zone: $(sudo firewall-cmd --get-default-zone 2>/dev/null)"
        action=$(gum choose --header "Firewall (firewalld)" \
            "Show active rules" "Enable" "Disable" "Allow a service" "Allow a port" \
            "Remove a port" "Back") || return 0
        case "$action" in
            "Show active rules") sudo firewall-cmd --list-all | pager; continue ;;
            "Enable")  svc_enable_now firewalld ;;
            "Disable") gum confirm "Stop firewalld?" --default=false && svc_stop firewalld ;;
            "Allow a service")
                local svc
                svc=$(sudo firewall-cmd --get-services | tr ' ' '\n' | gum filter --placeholder "service") || continue
                [ -n "$svc" ] && sudo firewall-cmd --permanent --add-service="$svc" && sudo firewall-cmd --reload ;;
            "Allow a port"|"Remove a port")
                local port op=--add-port
                [ "$action" = "Remove a port" ] && op=--remove-port
                port=$(gum input --placeholder "e.g. 8080/tcp or 6000-6010/udp") || continue
                [[ "$port" =~ ^[0-9]+(-[0-9]+)?/(tcp|udp)$ ]] || { err "Use PORT/tcp or PORT/udp"; pause; continue; }
                sudo firewall-cmd --permanent "$op=$port" && sudo firewall-cmd --reload ;;
            *) return 0 ;;
        esac
        pause
    done
}

if command_exists ufw; then
    ufw_menu
elif command_exists firewall-cmd; then
    firewalld_menu
else
    warn "No firewall tool found (ufw or firewalld)."
    if confirm "Install ufw and enable it (deny incoming, allow outgoing, allow SSH)?"; then
        pkg_install ufw || die "Could not install ufw."
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw allow 22/tcp
        sudo ufw --force enable
        svc_enable_now ufw || true
        ok "ufw enabled."
        pause
        ufw_menu
    fi
fi
