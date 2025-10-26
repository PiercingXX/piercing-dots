#!/bin/bash
# Hyprland wallpaper changer using hyprpaper and yazi

CONF="$HOME/.config/hypr/hyprpaper.conf"
WALLPAPER_DIR="$HOME/Pictures/backgrounds"

# Ensure wallpaper directory exists
if [ ! -d "$WALLPAPER_DIR" ]; then
    mkdir -p "$WALLPAPER_DIR"
    echo "Created $WALLPAPER_DIR directory. Please add wallpapers to this directory."
    exit 1
fi

# Check for required tools
tool_missing=false
for tool in hyprctl yazi; do
    if ! command -v "$tool" &>/dev/null; then
        echo "$tool not found. Please install $tool."
        tool_missing=true
    fi
done
if [ "$tool_missing" = true ]; then
    exit 1
fi

# Get connected displays (only valid display names)
mapfile -t displays < <(hyprctl monitors -j | grep -o '"name": *"[^"]*"' | awk -F '"' '{print $4}' | grep -E '^[A-Za-z]+-[0-9]+$')
if [ ${#displays[@]} -eq 0 ]; then
    echo "No displays found."
    exit 1
fi

# Ask user for mode if multiple displays
if [ ${#displays[@]} -gt 1 ]; then
    if command -v gum &>/dev/null; then
        mode=$(printf "Same wallpaper on all displays\nDifferent wallpaper for each display" | gum choose --header "Multiple displays detected. How do you want to set wallpapers?")
    else
        echo "Multiple displays detected."
        echo "1) Same wallpaper on all displays"
        echo "2) Different wallpaper for each display"
        read -rp "Choose [1-2]: " mode_choice
        if [ "$mode_choice" = "2" ]; then
            mode="Different wallpaper for each display"
        else
            mode="Same wallpaper on all displays"
        fi
    fi
else
    mode="Same wallpaper on all displays"
fi

# Function to select a wallpaper using yazi (with image preview)
select_wallpaper_yazi() {
    echo "Launching yazi in $WALLPAPER_DIR..." 1>&2
    local chooser_file selected_file
    chooser_file=$(mktemp)
    yazi "$WALLPAPER_DIR" --chooser-file "$chooser_file"
    selected_file=$(cat "$chooser_file")
    rm -f "$chooser_file"
    echo "yazi returned: $selected_file" 1>&2
    # Ensure absolute path
    if [ -n "$selected_file" ] && [ "${selected_file:0:1}" != "/" ]; then
        selected_file="$WALLPAPER_DIR/$selected_file"
    fi
    echo "$selected_file"
}

# Write new config (preload and wallpaper lines)
if [ "$mode" = "Same wallpaper on all displays" ]; then
    selected=$(select_wallpaper_yazi)
    if [ -z "$selected" ]; then
        echo "No wallpaper selected. Exiting."
        exit 0
    fi
    {
        awk '/^preload|^#|^splash|^$|^ipc/ {print}' "$CONF"
        for display in "${displays[@]}"; do
            echo "preload = $selected"
        done
        for display in "${displays[@]}"; do
            echo "wallpaper = $display,$selected"
        done
    } > "${CONF}.tmp" && mv "${CONF}.tmp" "$CONF"
    echo "Wallpaper set to $selected for displays: ${displays[*]}"
    # IPC: Preload, then set wallpaper
    hyprctl hyprpaper preload "$selected"
    for display in "${displays[@]}"; do
        hyprctl hyprpaper wallpaper "$display,$selected"
    done
else
    declare -A selected_wallpapers
    for display in "${displays[@]}"; do
        echo "\n--- Selecting wallpaper for display: $display ---"
        echo "Monitor info:"
        hyprctl monitors | grep -A 5 "^\s*ID.*$display" || echo "(No extra info found for $display)"
        wp=$(select_wallpaper_yazi)
        if [ -z "$wp" ]; then
            echo "No wallpaper selected for $display. Exiting."
            exit 0
        fi
        selected_wallpapers[$display]="$wp"
    done
    {
        awk '/^preload|^#|^splash|^$|^ipc/ {print}' "$CONF"
        for display in "${displays[@]}"; do
            echo "preload = ${selected_wallpapers[$display]}"
        done
        for display in "${displays[@]}"; do
            echo "wallpaper = $display,${selected_wallpapers[$display]}"
        done
    } > "${CONF}.tmp" && mv "${CONF}.tmp" "$CONF"
    echo "Wallpapers set for displays: ${displays[*]}"
    # IPC: Preload, then set wallpaper
    for display in "${displays[@]}"; do
        hyprctl hyprpaper preload "${selected_wallpapers[$display]}"
    done
    for display in "${displays[@]}"; do
        hyprctl hyprpaper wallpaper "$display,${selected_wallpapers[$display]}"
    done
fi
