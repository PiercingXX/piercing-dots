#!/bin/bash
# GitHub.com/PiercingXX
# Power & Night Light: power profile (power-profiles-daemon / TLP / tuned)
# and the hyprsunset night light on Hyprland.

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

command_exists gum || die "gum is required for this menu."

NIGHT_TEMP=2200   # matches dots/hypr/hyprsunset.conf

profile_backend() {
    if command_exists powerprofilesctl && powerprofilesctl get >/dev/null 2>&1; then echo ppd
    elif command_exists tlp; then echo tlp
    elif command_exists tuned-adm; then echo tuned
    fi
}

current_profile() {
    case "$(profile_backend)" in
        ppd)   powerprofilesctl get ;;
        tlp)   tlp-stat -s 2>/dev/null | awk -F'= *' '/^Mode/ {print $2; exit}' ;;
        tuned) tuned-adm active 2>/dev/null | sed 's/^Current active profile: //' ;;
        *)     echo "n/a" ;;
    esac
}

set_profile() {
    local pick
    case "$(profile_backend)" in
        ppd)
            pick=$(powerprofilesctl list | grep -oE '^[ *] *[a-z-]+:' | tr -d ' *:' \
                | gum choose --header "Power profile (now: $(current_profile))") || return 0
            [ -n "$pick" ] && powerprofilesctl set "$pick" ;;
        tlp)
            pick=$(gum choose --header "TLP mode (now: $(current_profile))" "Auto (follow AC/battery)" "AC" "Battery") || return 0
            case "$pick" in
                Auto*)   sudo tlp start ;;
                AC)      sudo tlp ac ;;
                Battery) sudo tlp bat ;;
            esac ;;
        tuned)
            pick=$(tuned-adm list 2>/dev/null | sed -n 's/^- \([^ ]*\).*/\1/p' \
                | gum filter --placeholder "tuned profile (now: $(current_profile))") || return 0
            [ -n "$pick" ] && sudo tuned-adm profile "$pick" ;;
        *)
            warn "No power profile tool found (power-profiles-daemon, TLP or tuned)." ;;
    esac
}

nightlight_available() {
    [ "$(detect_wm)" = hyprland ] && command_exists hyprsunset
}

nightlight_toggle() {
    # Reuse the eww toggle so the bar state stays in sync when present
    local eww_toggle="$HOME/.config/eww/scripts/nightlight"
    if [ -x "$eww_toggle" ]; then
        "$eww_toggle" toggle
        return
    fi
    pgrep -x hyprsunset >/dev/null 2>&1 || { setsid -f hyprsunset >/dev/null 2>&1; sleep 0.3; }
    local t
    t=$(hyprctl hyprsunset temperature 2>/dev/null | tr -dc '0-9')
    if [ -n "$t" ] && [ "$t" -lt 5000 ]; then
        hyprctl hyprsunset identity >/dev/null
        ok "Night light off."
    else
        hyprctl hyprsunset temperature "$NIGHT_TEMP" >/dev/null
        ok "Night light on (${NIGHT_TEMP}K)."
    fi
}

nightlight_temperature() {
    local t
    t=$(gum input --placeholder "temperature in Kelvin (1000-6500)" --value "$NIGHT_TEMP") || return 0
    [[ "$t" =~ ^[0-9]{4}$ ]] && [ "$t" -ge 1000 ] && [ "$t" -le 6500 ] || { err "Enter 1000-6500."; return 1; }
    pgrep -x hyprsunset >/dev/null 2>&1 || { setsid -f hyprsunset >/dev/null 2>&1; sleep 0.3; }
    hyprctl hyprsunset temperature "$t" >/dev/null && ok "Night light set to ${t}K."
}

while true; do
    clear
    echo "Power profile: $(current_profile)"
    options=("Power profile")
    if nightlight_available; then
        options+=("Toggle night light" "Night light temperature")
    fi
    options+=("Back")
    choice=$(printf '%s\n' "${options[@]}" | gum choose --header "Power & Night Light") || exit 0
    case "$choice" in
        "Power profile")           set_profile ;;
        "Toggle night light")      nightlight_toggle ;;
        "Night light temperature") nightlight_temperature ;;
        *) exit 0 ;;
    esac
    pause
done
