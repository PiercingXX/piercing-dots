#!/bin/bash
# GitHub.com/PiercingXX
# Screenshot helper for every WM in the rice.
# Usage: wm-screenshot.sh [region|select|window|full|fulltime|selecttime]
#   *time modes wait 5 seconds first.
# Backends: hyprshot (Hyprland) > grim+slurp (any wlroots/Hyprland) > flameshot (X11)

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

mode="${1:-region}"
DELAY=5
QUICK_TIMEOUT=1500

case "$mode" in
    region|select)   kind=region ;;
    selecttime)      kind=region; sleep "$DELAY" ;;
    window)          kind=window ;;
    full)            kind=full ;;
    fulltime)        kind=full; sleep "$DELAY" ;;
    *)
        echo "Usage: $(basename "$0") [region|select|window|full|fulltime|selecttime]" >&2
        exit 2 ;;
esac

screenshot_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
shot_name="$(date +%F-%H%M%S).png"
shot_file="$screenshot_dir/$shot_name"

notify_saved() {
    notify_replace screenshot low "$QUICK_TIMEOUT" camera-photo "Screenshot saved" "$1"
}

wm=$(detect_wm)

# Real hyprshot only on Hyprland (linux-mod may drop a grim shim with the same name)
real_hyprshot() {
    local bin
    bin=$(command -v hyprshot) || return 1
    ! grep -q 'linux-mod hyprshot shim' "$bin" 2>/dev/null
}

if is_wayland; then
    mkdir -p "$screenshot_dir"

    if [ "$wm" = hyprland ] && real_hyprshot; then
        case "$kind" in
            region) hyprshot -s -m region -o "$screenshot_dir" -f "$shot_name" ;;
            window) hyprshot -s -m window -m active -o "$screenshot_dir" -f "$shot_name" ;;
            full)   hyprshot -s -m output -m active -o "$screenshot_dir" -f "$shot_name" ;;
        esac
        # hyprshot returns 0 even when the selection is cancelled; trust the file
        [ -f "$shot_file" ] && notify_saved "$shot_file"
        exit 0
    fi

    if command_exists grim; then
        geometry=""
        case "$kind" in
            region)
                command_exists slurp || { notify_replace screenshot normal 3000 dialog-error "Screenshot" "slurp is not installed"; exit 1; }
                geometry="$(slurp)" || exit 0
                [ -n "$geometry" ] || exit 0
                ;;
            window)
                case "$wm" in
                    hyprland)
                        geometry="$(hyprctl activewindow -j 2>/dev/null \
                            | jq -r 'select(.at) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" ;;
                    sway)
                        geometry="$(swaymsg -t get_tree \
                            | jq -r 'recurse(.nodes[]?, .floating_nodes[]?) | select(.focused) | .rect | "\(.x),\(.y) \(.width)x\(.height)"' \
                            | head -n 1)" ;;
                esac
                # Unknown compositor: let the user drag the window area
                if [ -z "$geometry" ] && command_exists slurp; then
                    geometry="$(slurp)" || exit 0
                fi
                [ -n "$geometry" ] || exit 0
                ;;
            full)
                if [ "$wm" = hyprland ]; then
                    focused_output="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name')"
                elif [ "$wm" = sway ]; then
                    focused_output="$(swaymsg -t get_outputs | jq -r '.[] | select(.focused) | .name')"
                fi
                ;;
        esac

        if [ -n "$geometry" ]; then
            grim -g "$geometry" "$shot_file"
        elif [ -n "${focused_output:-}" ]; then
            grim -o "$focused_output" "$shot_file"
        else
            grim "$shot_file"
        fi || exit 1

        command_exists wl-copy && wl-copy < "$shot_file"
        notify_saved "$shot_file"
        exit 0
    fi
fi

if ! command_exists flameshot; then
    notify_replace screenshot normal 3000 dialog-error "Screenshot" "Install grim+slurp (Wayland) or flameshot (X11)."
    echo "No screenshot backend found: install grim+slurp (Wayland) or flameshot (X11)." >&2
    exit 1
fi

mkdir -p "$screenshot_dir"
case "$kind" in
    full)   flameshot full -c -p "$screenshot_dir" ;;
    window|region) flameshot gui --clipboard -p "$screenshot_dir" ;;
esac
notify_replace screenshot low "$QUICK_TIMEOUT" camera-photo "Screenshot captured" "Copied to clipboard and saved to $screenshot_dir"
