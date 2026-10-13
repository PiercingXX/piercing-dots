#!/bin/bash
# GitHub.com/PiercingXX
# Keyboard Layout: switch the running session's layout (Hyprland, Sway, X11),
# optionally save it to the Hyprland config, and set the system default
# (TTY + X11) with localectl. install.sh defaults everything to us/colemak.

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
detect_distro

command_exists gum || die "gum is required for this menu."

HYPR_GENERAL="$HOME/.config/hypr/hyprland/general.lua"

# label|xkb layout|xkb variant|tty keymap
PRESETS=(
    "US Colemak|us|colemak|colemak"
    "US Colemak-DH|us|colemak_dh|colemak"
    "US QWERTY|us||us"
    "US Dvorak|us|dvorak|dvorak"
    "UK QWERTY|gb||uk"
    "German QWERTZ|de||de"
)

show_current() {
    echo "Session: $(detect_wm)"
    case "$(detect_wm)" in
        hyprland)
            echo "Hyprland: $(hyprctl getoption input:kb_layout 2>/dev/null | awk '/str:/ {print $2}') $(hyprctl getoption input:kb_variant 2>/dev/null | awk '/str:/ {print $2}')" ;;
        sway)
            command_exists jq && echo "Sway: $(swaymsg -t get_inputs -r | jq -r '[.[] | select(.type=="keyboard") | .xkb_active_layout_name][0]')" ;;
    esac
    if command_exists localectl && [ "$INIT" = systemd ]; then
        localectl status | sed -n 's/^ *//; /Keymap\|Layout\|Variant/p'
    fi
    echo
}

apply_session() {
    local layout="$1" variant="$2"
    case "$(detect_wm)" in
        hyprland)
            hyprctl keyword input:kb_layout "$layout" >/dev/null
            hyprctl keyword input:kb_variant "$variant" >/dev/null ;;
        sway)
            swaymsg "input type:keyboard xkb_layout $layout" >/dev/null
            swaymsg "input type:keyboard xkb_variant \"$variant\"" >/dev/null ;;
        gnome)
            local src="('xkb', '$layout${variant:++$variant}')"
            gsettings set org.gnome.desktop.input-sources sources "[$src]" ;;
        *)
            if [ -n "${DISPLAY:-}" ] && command_exists setxkbmap; then
                if [ -n "$variant" ]; then setxkbmap -layout "$layout" -variant "$variant"; else setxkbmap -layout "$layout"; fi
            else
                warn "Don't know how to switch the layout live for this session."
                return 1
            fi ;;
    esac
    ok "Session layout: $layout ${variant:-(no variant)}"
}

save_hyprland() {
    local layout="$1" variant="$2"
    [ -f "$HYPR_GENERAL" ] || { warn "$HYPR_GENERAL not found."; return 1; }
    grep -qE '^[[:space:]]*kb_layout[[:space:]]*=' "$HYPR_GENERAL" || { warn "No kb_layout line in $HYPR_GENERAL."; return 1; }
    sed -i -E \
        -e "s/^([[:space:]]*kb_layout[[:space:]]*=[[:space:]]*)\"[^\"]*\"/\1\"$layout\"/" \
        -e "s/^([[:space:]]*kb_variant[[:space:]]*=[[:space:]]*)\"[^\"]*\"/\1\"$variant\"/" \
        "$HYPR_GENERAL"
    ok "Saved to $HYPR_GENERAL (Update PiercingXX Rice will reset it to Colemak)."
}

save_system() {
    local layout="$1" variant="$2" keymap="$3"
    if command_exists localectl && [ "$INIT" = systemd ]; then
        sudo localectl set-keymap "$keymap" && sudo localectl set-x11-keymap "$layout" "" "$variant" \
            && ok "System default (TTY + X11) set."
    elif [ -f /etc/vconsole.conf ] || [ -f /etc/conf.d/keymaps ]; then
        [ -f /etc/vconsole.conf ] && sudo sed -i "s/^KEYMAP=.*/KEYMAP=$keymap/" /etc/vconsole.conf
        [ -f /etc/conf.d/keymaps ] && sudo sed -i "s/^keymap=.*/keymap=\"$keymap\"/" /etc/conf.d/keymaps
        ok "TTY keymap set to $keymap (takes effect next boot)."
    else
        warn "No supported way to set the system keymap here."
    fi
}

while true; do
    clear
    show_current
    labels=()
    for row in "${PRESETS[@]}"; do labels+=("${row%%|*}"); done
    pick=$(printf '%s\n' "${labels[@]}" "Custom..." "Back" | gum choose --header "Keyboard layout") || exit 0
    case "$pick" in
        "Back"|"") exit 0 ;;
        "Custom...")
            layout=$(gum input --placeholder "xkb layout, e.g. us, de, fr") || continue
            variant=$(gum input --placeholder "xkb variant (blank for none), e.g. colemak") || continue
            keymap=$(gum input --placeholder "TTY keymap, e.g. us, colemak" --value "$layout") || continue
            [[ "$layout" =~ ^[a-z]{2,8}$ ]] && [[ -z "$variant" || "$variant" =~ ^[a-z0-9_-]+$ ]] \
                || { err "Invalid layout/variant."; pause; continue; } ;;
        *)
            for row in "${PRESETS[@]}"; do
                [ "${row%%|*}" = "$pick" ] || continue
                IFS='|' read -r _ layout variant keymap <<< "$row"
            done ;;
    esac

    apply_session "$layout" "$variant"
    if [ "$(detect_wm)" = hyprland ] && gum confirm "Also save it to the Hyprland config?" --default=false; then
        save_hyprland "$layout" "$variant"
    fi
    if gum confirm "Also make it the system default (TTY + login screen)?" --default=false; then
        save_system "$layout" "$variant" "$keymap"
    fi
    pause
done
