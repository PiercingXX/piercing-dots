#!/bin/bash
# GitHub.com/PiercingXX
# Pick a wallpaper with yazi and apply it for the running desktop:
#   Hyprland -> hyprpaper (IPC, config written for next login)
#   Sway     -> swaybg
#   GNOME    -> gsettings
#   X11 WMs  -> ~/.config/wall.png (read by bspwm/dwm/i3 autostarts) + feh/hsetroot

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

WALLPAPER_DIR="$HOME/Pictures/backgrounds"

YAZI_BIN="$(command -v yazi 2>/dev/null || true)"
if [[ -z "$YAZI_BIN" && -x "$HOME/.cargo/bin/yazi" ]]; then
    YAZI_BIN="$HOME/.cargo/bin/yazi"
fi

clear
if [ ! -d "$WALLPAPER_DIR" ]; then
    mkdir -p "$WALLPAPER_DIR"
    die "Created $WALLPAPER_DIR. Add some wallpapers there and run this again."
fi
[ -n "$YAZI_BIN" ] || die "yazi not found. Please install yazi."

# Pick one image with yazi (image preview) -> absolute path on stdout
select_wallpaper() {
    local chooser_file selected_file
    echo "Launching yazi in $WALLPAPER_DIR..." >&2
    chooser_file=$(mktemp)
    "$YAZI_BIN" "$WALLPAPER_DIR" --chooser-file "$chooser_file"
    selected_file=$(head -n 1 "$chooser_file")
    rm -f "$chooser_file"
    if [ -n "$selected_file" ] && [ "${selected_file:0:1}" != "/" ]; then
        selected_file="$WALLPAPER_DIR/$selected_file"
    fi
    echo "$selected_file"
}

# Remember the choice for X11 WMs whose autostart reads ~/.config/wall.png
remember_wallpaper() {
    ln -sf "$1" "$HOME/.config/wall.png"
}

choose_mode() {
    if command_exists gum; then
        printf "Same wallpaper on all displays\nDifferent wallpaper for each display" \
            | gum choose --header "Multiple displays detected. How do you want to set wallpapers?"
    else
        local c
        echo "Multiple displays detected."
        echo "1) Same wallpaper on all displays"
        echo "2) Different wallpaper for each display"
        read -rp "Choose [1-2]: " c
        [ "$c" = 2 ] && echo "Different wallpaper for each display" || echo "Same wallpaper on all displays"
    fi
}

# ---------------------------------------------------------------------------
# Hyprland / hyprpaper
# ---------------------------------------------------------------------------
hyprland_wallpaper() {
    local conf="$HOME/.config/hypr/hyprpaper.conf"
    # ~/.local/bin/hyprpaper overrides the packaged one (same rule as execs.lua)
    local hyprpaper_bin="$HOME/.local/bin/hyprpaper"
    [ -x "$hyprpaper_bin" ] || hyprpaper_bin="hyprpaper"

    command_exists hyprctl || die "hyprctl not found."
    command_exists jq || die "jq not found (needed to read monitor names)."
    mkdir -p "$(dirname "$conf")"
    [ -f "$conf" ] || printf 'splash = false\nipc = true\n' > "$conf"

    local -a displays
    mapfile -t displays < <(hyprctl monitors -j | jq -r '.[].name')
    [ ${#displays[@]} -gt 0 ] || die "No displays found."

    local mode="Same wallpaper on all displays"
    [ ${#displays[@]} -gt 1 ] && mode=$(choose_mode)
    [ -n "$mode" ] || exit 0

    declare -A chosen
    local display wp
    if [ "$mode" = "Same wallpaper on all displays" ]; then
        wp=$(select_wallpaper)
        [ -n "$wp" ] || { echo "No wallpaper selected."; exit 0; }
        for display in "${displays[@]}"; do chosen[$display]="$wp"; done
    else
        for display in "${displays[@]}"; do
            printf '\n--- Selecting wallpaper for display: %s ---\n' "$display"
            hyprctl monitors -j | jq -r --arg m "$display" \
                '.[] | select(.name == $m) | "\(.description)  \(.width)x\(.height)@\(.refreshRate|floor)"'
            wp=$(select_wallpaper)
            [ -n "$wp" ] || { echo "No wallpaper selected for $display."; exit 0; }
            chosen[$display]="$wp"
        done
    fi

    # Rewrite the config: drop old wallpaper/preload entries, write one block per
    # monitor plus a catch-all block (monitor = empty) for hot-plugged displays.
    local fallback="${chosen[${displays[0]}]}"
    {
        awk '
            /^wallpaper[[:space:]]*\{/ { in_block=1 }
            in_block && /\}/ { in_block=0; next }
            in_block { next }
            /^preload[[:space:]]*=/ || /^wallpaper[[:space:]]*=/ { next }
            { print }
        ' "$conf" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
        for display in "${displays[@]}"; do
            printf '\nwallpaper {\n    monitor = %s\n    path = %s\n    fit_mode = cover\n}\n' "$display" "${chosen[$display]}"
        done
        printf '\n# Any other monitor\nwallpaper {\n    monitor =\n    path = %s\n    fit_mode = cover\n}\n' "$fallback"
    } > "${conf}.tmp" && mv "${conf}.tmp" "$conf"

    # Live update over IPC; restart the daemon only if IPC isn't answering
    local ipc_ok=1
    if pgrep -x hyprpaper >/dev/null 2>&1; then
        for display in "${displays[@]}"; do
            out=$(hyprctl hyprpaper wallpaper "$display,${chosen[$display]},cover" 2>&1)
            [[ "$out" == *ok* ]] || ipc_ok=0
        done
    else
        ipc_ok=0
    fi
    if [ $ipc_ok -eq 0 ]; then
        if systemctl --user is-active --quiet hyprpaper.service 2>/dev/null; then
            systemctl --user restart hyprpaper.service
        else
            pkill -x hyprpaper >/dev/null 2>&1 || true
            setsid -f "$hyprpaper_bin" -c "$conf" >/dev/null 2>&1
        fi
    fi
    remember_wallpaper "$fallback"
    ok "Wallpaper set for: ${displays[*]}"
}

# ---------------------------------------------------------------------------
# Sway / swaybg
# ---------------------------------------------------------------------------
sway_wallpaper() {
    local wp
    command_exists swaybg || die "swaybg not found. Please install swaybg."
    wp=$(select_wallpaper)
    [ -n "$wp" ] || { echo "No wallpaper selected."; exit 0; }
    if command_exists swaymsg; then
        # sway's own bg command persists for the session without a helper process
        swaymsg "output * bg \"$wp\" fill" >/dev/null 2>&1 || {
            pkill -x swaybg >/dev/null 2>&1 || true
            setsid -f swaybg -i "$wp" -m fill >/dev/null 2>&1
        }
    else
        pkill -x swaybg >/dev/null 2>&1 || true
        setsid -f swaybg -i "$wp" -m fill >/dev/null 2>&1
    fi
    remember_wallpaper "$wp"
    ok "Wallpaper set to $wp for Sway."
}

# ---------------------------------------------------------------------------
# GNOME
# ---------------------------------------------------------------------------
gnome_wallpaper() {
    local wp
    command_exists gsettings || die "gsettings not found (part of GNOME)."
    wp=$(select_wallpaper)
    [ -n "$wp" ] || { echo "No wallpaper selected."; exit 0; }
    gsettings set org.gnome.desktop.background picture-uri "file://$wp"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$wp" 2>/dev/null
    ok "Wallpaper set to $wp for GNOME."
}

# ---------------------------------------------------------------------------
# X11 window managers (i3, bspwm, herbstluftwm, dwm, qtile, awesome)
# ---------------------------------------------------------------------------
x11_wallpaper() {
    local wm="$1" wp
    wp=$(select_wallpaper)
    [ -n "$wp" ] || { echo "No wallpaper selected."; exit 0; }
    remember_wallpaper "$wp"
    if [ "$wm" = awesome ] && command_exists awesome-client; then
        awesome-client "require('gears').wallpaper.maximized('$wp', nil, true)" >/dev/null 2>&1 \
            && { ok "Wallpaper set to $wp for awesome."; return; }
    fi
    if command_exists feh; then
        feh --bg-fill --no-fehbg "$wp"
    elif command_exists hsetroot; then
        hsetroot -cover "$wp"
    elif command_exists xwallpaper; then
        xwallpaper --zoom "$wp"
    else
        die "Install feh, hsetroot or xwallpaper to set the wallpaper."
    fi
    ok "Wallpaper set to $wp for $wm (saved as ~/.config/wall.png)."
}

wm=$(detect_wm)
case "$wm" in
    hyprland) hyprland_wallpaper ;;
    sway)     sway_wallpaper ;;
    gnome)    gnome_wallpaper ;;
    i3|bspwm|herbstluftwm|dwm|qtile|awesome|x11)
        x11_wallpaper "$wm" ;;
    *)
        die "Unsupported desktop: $wm (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset})" ;;
esac
