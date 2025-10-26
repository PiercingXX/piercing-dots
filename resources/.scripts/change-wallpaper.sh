#!/bin/bash
# GitHub.com/PiercingXX

# Change wallpaper using hyprpaper, based on hyprpaper.conf

CONF="$HOME/.config/hypr/hyprpaper.conf"
DEFAULT_CONF="/home/dr3k/Documents/GitHub/piercing-dots/dots/hypr/hyprpaper.conf"

# If user config doesn't exist, copy default
if [ ! -f "$CONF" ]; then
    mkdir -p "$(dirname "$CONF")"
    cp "$DEFAULT_CONF" "$CONF"
fi


# List all images in $HOME/Pictures/Backgrounds
WALLPAPER_DIR="$HOME/Pictures/Backgrounds"
if [ ! -d "$WALLPAPER_DIR" ]; then
    echo "No $WALLPAPER_DIR directory found."
    exit 1
fi
mapfile -t wallpapers < <(find "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' \ ))
if [ ${#wallpapers[@]} -eq 0 ]; then
    echo "No wallpapers found in $WALLPAPER_DIR."
    exit 1
fi

# Use gum to select wallpaper
if ! command -v gum &>/dev/null; then
    echo "gum not found. Please install gum for a modern menu."
    exit 1
fi


selected=$(printf "%s\n" "${wallpapers[@]}" | gum choose --header "Select a wallpaper to set")
[ -z "$selected" ] && exit 0


# Update all wallpaper lines in config to use the selected image
sed -i "/^wallpaper =/s|,.*|,$selected|" "$CONF"

# Reload hyprpaper (if running)
if pgrep -x hyprpaper >/dev/null; then
    pkill -SIGUSR1 hyprpaper
fi

echo "Wallpaper set to $selected."
