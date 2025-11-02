#!/bin/bash
# GitHub.com/PiercingXX

# --- Desktop Environment Check ---
DE="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-$(echo $XDG_SESSION_DESKTOP)}}"
if [[ "$DE" =~ [Hh]yprland ]]; then
    # ...existing code for Hyprland...
    CONF="$HOME/.config/hypr/hyprpaper.conf"
    WALLPAPER_DIR="$HOME/Pictures/backgrounds"
    clear
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
        awk '! /^preload / && ! /^wallpaper /' "$CONF"
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
            awk '! /^preload / && ! /^wallpaper /' "$CONF"
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
    exit 0
elif [[ "$DE" =~ [Gg][Nn][Oo][Mm][Ee] ]]; then
    # --- GNOME wallpaper changer ---
    WALLPAPER_DIR="$HOME/Pictures/backgrounds"
    clear
    if [ ! -d "$WALLPAPER_DIR" ]; then
        mkdir -p "$WALLPAPER_DIR"
        echo "Created $WALLPAPER_DIR directory. Please add wallpapers to this directory."
        exit 1
    fi
    if ! command -v yazi &>/dev/null; then
        echo "yazi not found. Please install yazi."
        exit 1
    fi
    if ! command -v gsettings &>/dev/null; then
        echo "gsettings not found. Please install gsettings (usually part of GNOME)."
        exit 1
    fi
    # Select wallpaper using yazi
    echo "Launching yazi in $WALLPAPER_DIR..." 1>&2
    chooser_file=$(mktemp)
    yazi "$WALLPAPER_DIR" --chooser-file "$chooser_file"
    selected_file=$(cat "$chooser_file")
    rm -f "$chooser_file"
    if [ -z "$selected_file" ]; then
        echo "No wallpaper selected. Exiting."
        exit 0
    fi
    # Ensure absolute path
    if [ "${selected_file:0:1}" != "/" ]; then
        selected_file="$WALLPAPER_DIR/$selected_file"
    fi
    # Set wallpaper using gsettings
    gsettings set org.gnome.desktop.background picture-uri "file://$selected_file"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$selected_file" 2>/dev/null
    echo "Wallpaper set to $selected_file for GNOME."
    exit 0
elif [[ "$DE" =~ [Ii]3 ]]; then
    # --- i3 wallpaper changer ---
    WALLPAPER_DIR="$HOME/Pictures/backgrounds"
    clear
    if [ ! -d "$WALLPAPER_DIR" ]; then
        mkdir -p "$WALLPAPER_DIR"
        echo "Created $WALLPAPER_DIR directory. Please add wallpapers to this directory."
        exit 1
    fi
    if ! command -v yazi &>/dev/null; then
        echo "yazi not found. Please install yazi."
        exit 1
    fi
    if ! command -v feh &>/dev/null; then
        echo "feh not found. Please install feh."
        exit 1
    fi
    # Select wallpaper using yazi
    echo "Launching yazi in $WALLPAPER_DIR..." 1>&2
    chooser_file=$(mktemp)
    yazi "$WALLPAPER_DIR" --chooser-file "$chooser_file"
    selected_file=$(cat "$chooser_file")
    rm -f "$chooser_file"
    if [ -z "$selected_file" ]; then
        echo "No wallpaper selected. Exiting."
        exit 0
    fi
    # Ensure absolute path
    if [ "${selected_file:0:1}" != "/" ]; then
        selected_file="$WALLPAPER_DIR/$selected_file"
    fi
    # Set wallpaper using feh
    feh --bg-fill "$selected_file"
    echo "Wallpaper set to $selected_file for i3."
    exit 0
else
    echo "Unsupported desktop environment: $DE"
    exit 1
fi
