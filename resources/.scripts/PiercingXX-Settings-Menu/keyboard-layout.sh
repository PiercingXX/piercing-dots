#!/bin/bash
# GitHub.com/PiercingXX
# Keyboard Layout: switch the running session's layout (Hyprland, Sway, X11),
# optionally save it to the Hyprland config, and set the system default
# (TTY + X11) with localectl. install.sh defaults everything to us/colemak.
#
# Piercing Num / Piercing Sym come from github.com/PiercingXX/piercing-keyboard-layout:
# picking one installs it to ~/.config/xkb first if needed. Their system-wide
# route is keyd, since localectl and the TTY only know the stock keymaps.
# PIERCING_KEYBOARD_DIR=/path/to/clone uses a local checkout instead of cloning.

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
detect_distro

command_exists gum || die "gum is required for this menu."

HYPR_GENERAL="$HOME/.config/hypr/hyprland/general.lua"
XKB_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/xkb"
PIERCING_REPO="https://github.com/PiercingXX/piercing-keyboard-layout.git"
PIERCING_TMP=""
PIERCING_SRC=""
trap '[ -n "$PIERCING_TMP" ] && command rm -rf "$PIERCING_TMP"' EXIT

# label|xkb layout|xkb variant|tty keymap (Piercing has none; keyd covers the TTY)
PRESETS=(
    "Piercing Num|piercing-num||"
    "Piercing Sym|piercing-sym||"
    "US Colemak|us|colemak|colemak"
    "US Colemak-DH|us|colemak_dh|colemak"
    "US QWERTY|us||us"
    "US Dvorak|us|dvorak|dvorak"
    "UK QWERTY|gb||uk"
    "German QWERTZ|de||de"
)

is_piercing() { [[ "$1" == piercing* ]]; }

# Set PIERCING_SRC to a piercing-keyboard-layout checkout, cloned once per run.
# Not called in $(...): the clone's temp dir has to reach the EXIT trap.
piercing_src() {
    [ -n "$PIERCING_SRC" ] && return 0
    if [ -n "${PIERCING_KEYBOARD_DIR:-}" ]; then
        PIERCING_SRC="$PIERCING_KEYBOARD_DIR"
        return 0
    fi
    command_exists git || { err "git is needed to fetch the Piercing layouts."; return 1; }
    PIERCING_TMP=$(mktemp -d)
    git clone --depth 1 -q "$PIERCING_REPO" "$PIERCING_TMP/kb" \
        || { err "Could not clone $PIERCING_REPO."; return 1; }
    PIERCING_SRC="$PIERCING_TMP/kb"
}

piercing_installed() {
    [ -f "$XKB_USER_DIR/symbols/$1" ] && grep -q "<name>$1</name>" "$XKB_USER_DIR/rules/evdev.xml" 2>/dev/null
}

# Install (or refresh) a Piercing variant's xkb files under ~/.config/xkb
install_piercing() {
    local layout="$1"
    piercing_src || return 1
    [ -x "$PIERCING_SRC/$layout/linux/install.sh" ] || { err "No installer for $layout in $PIERCING_SRC."; return 1; }
    # Only the install lines; the installer's how-to-activate notes are what this menu does
    "$PIERCING_SRC/$layout/linux/install.sh" | sed -n '/^Installed\|^Merged\|^Already\|^Verified\|^NOTE/p'
}

ensure_piercing() {
    piercing_installed "$1" && return 0
    say "Installing $1 from piercing-keyboard-layout..."
    install_piercing "$1" && piercing_installed "$1"
}

show_current() {
    echo "Session: $(detect_wm)"
    case "$(detect_wm)" in
        hyprland)
            echo "Hyprland: $(hyprctl getoption input:kb_layout 2>/dev/null | awk '/str:/ {print $2}') $(hyprctl getoption input:kb_variant 2>/dev/null | awk '/str:/ {print $2}')" ;;
        sway)
            command_exists jq && echo "Sway: $(swaymsg -t get_inputs -r | jq -r '[.[] | select(.type=="keyboard") | .xkb_active_layout_name][0]')" ;;
        gnome)
            echo "GNOME: $(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null)" ;;
        *)
            [ -n "${DISPLAY:-}" ] && command_exists setxkbmap \
                && echo "X11: $(setxkbmap -query | awk '/layout|variant/ {printf "%s ", $2}')" ;;
    esac
    local l
    for l in piercing-num piercing-sym; do
        piercing_installed "$l" && echo "Installed: $l"
    done
    [ -f /etc/keyd/default.conf ] && echo "keyd: /etc/keyd/default.conf present (system-wide remap)"
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
                if is_piercing "$layout"; then
                    # User-level layouts need -I; plain setxkbmap can't find them
                    command_exists xkbcomp || { warn "xkbcomp is needed for user-level layouts on X11."; return 1; }
                    setxkbmap -I"$XKB_USER_DIR" "$layout" -print | xkbcomp -I"$XKB_USER_DIR" - "$DISPLAY" 2>/dev/null
                elif [ -n "$variant" ]; then setxkbmap -layout "$layout" -variant "$variant"; else setxkbmap -layout "$layout"; fi
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

# Piercing system-wide: keyd remaps at the evdev level (login screen, TTY,
# every session), so the session itself has to go back to plain us
# or the letters get remapped twice.
save_system_keyd() {
    local layout="$1"
    if ! command_exists keyd && ! command_exists keyd.rvaiya; then
        say "Installing keyd..."
        pkg_install keyd || { err "keyd isn't available from $PKG here; install it and try again."; return 1; }
    fi
    svc_enable_now keyd >/dev/null 2>&1 || true
    piercing_src || return 1
    "$PIERCING_SRC/$layout/linux/keyd/install.sh" >/dev/null || { err "keyd install failed."; return 1; }
    ok "keyd now maps $layout system-wide (/etc/keyd/default.conf)."
    say "Switching the session and system defaults to plain us so keys aren't remapped twice."
    apply_session us ""
    if [ "$(detect_wm)" = hyprland ] && [ -f "$HYPR_GENERAL" ]; then
        save_hyprland us ""
    fi
    if command_exists localectl && [ "$INIT" = systemd ]; then
        sudo localectl set-keymap us && sudo localectl set-x11-keymap us "" ""
    fi
}

save_system() {
    local layout="$1" variant="$2" keymap="$3"
    if is_piercing "$layout"; then
        save_system_keyd "$layout"
        return
    fi
    if [ -f /etc/keyd/default.conf ]; then
        warn "keyd is remapping keys system-wide; $layout would be layered on top of it."
        if gum confirm "Remove /etc/keyd/default.conf first?" --default=true; then
            sudo mv /etc/keyd/default.conf /etc/keyd/default.conf.off \
                && { sudo keyd reload 2>/dev/null || sudo keyd.rvaiya reload 2>/dev/null || true; } \
                && ok "keyd config moved to /etc/keyd/default.conf.off."
        fi
    fi
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
    pick=$(printf '%s\n' "${labels[@]}" "Custom..." "Update Piercing layouts" "Back" | gum choose --header "Keyboard layout") || exit 0
    case "$pick" in
        "Back"|"") exit 0 ;;
        "Update Piercing layouts")
            for l in piercing-num piercing-sym; do
                piercing_installed "$l" || continue
                say "Updating $l..."
                install_piercing "$l"
            done
            pause
            continue ;;
        "Custom...")
            layout=$(gum input --placeholder "xkb layout, e.g. us, de, fr") || continue
            variant=$(gum input --placeholder "xkb variant (blank for none), e.g. colemak") || continue
            keymap=$(gum input --placeholder "TTY keymap, e.g. us, colemak" --value "$layout") || continue
            [[ "$layout" =~ ^[a-z][a-z0-9-]{1,23}$ ]] && [[ -z "$variant" || "$variant" =~ ^[a-z0-9_-]+$ ]] \
                || { err "Invalid layout/variant."; pause; continue; } ;;
        *)
            for row in "${PRESETS[@]}"; do
                [ "${row%%|*}" = "$pick" ] || continue
                IFS='|' read -r _ layout variant keymap <<< "$row"
            done ;;
    esac

    if is_piercing "$layout" && ! ensure_piercing "$layout"; then
        err "$layout isn't installed; nothing changed."
        pause
        continue
    fi
    apply_session "$layout" "$variant"
    if [ "$(detect_wm)" = hyprland ] && gum confirm "Also save it to the Hyprland config?" --default=false; then
        save_hyprland "$layout" "$variant"
    fi
    sys_prompt="Also make it the system default (TTY + login screen)?"
    is_piercing "$layout" && sys_prompt="Also use it at the TTY + login screen? (installs keyd, system-wide)"
    if gum confirm "$sys_prompt" --default=false; then
        save_system "$layout" "$variant" "$keymap"
    fi
    pause
done
