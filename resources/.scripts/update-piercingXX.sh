#!/bin/bash
# GitHub.com/PiercingXX

# Check/install gum if missing
if ! command -v gum &> /dev/null; then
    echo "gum not found. Installing..."
    if command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm gum
    else
        echo "Please install gum manually."
        exit 1
    fi
fi

username=$(id -u -n 1000)
builddir=$(pwd)

# Menu for PiercingXX options
while true; do
    clear
    choice=$(printf "%s\n" \
        "PiercingXX Rice" \
        "Piercing Gimp Only" \
        "Rice-No Hyprland" \
        "Exit" | \
        gum choose --header "PiercingXX Update Options" --cursor.foreground 212 --selected.foreground 212)
    case $choice in
        "PiercingXX Rice")
            echo -e "\033[1;33mDownloading and Applying PiercingXX Rice...\033[0m"
            rm -rf piercing-dots
            git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git
            chmod -R u+x piercing-dots
            cd piercing-dots || exit
            ./install.sh
            cd "$builddir" || exit
            rm -rf piercing-dots
            echo -e "\033[0;32mPiercingXX Rice Applied Successfully!\033[0m"
            ;;
        "Piercing Gimp Only")
            echo -e "\033[1;33mInstalling Piercing Gimp Presets...\033[0m"
            rm -rf piercing-dots
            git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git
            chmod -R u+x piercing-dots
            cd piercing-dots/scripts || exit
            ./gimp-mod.sh
            cd "$builddir" || exit
            rm -rf piercing-dots
            echo -e "\033[0;32mPiercing Gimp Presets Installed Successfully!\033[0m"
            ;;
        "Rice-No Hyprland")
            echo -e "\033[1;33mDownloading and Applying PiercingXX Rice w/o Hyprdots...\033[0m"
            rm -rf piercing-dots
            git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git
            chmod -R u+x piercing-dots
            cd piercing-dots || exit
            cp -pf dots/hypr/hyprland/keybinds.conf /home/"$username"/.config/hypr/hyprland/
            rm -rf dots/hypr
            ./install.sh
            cd "$builddir" || exit
            rm -rf piercing-dots
            echo -e "\033[0;32mPiercingXX Rice Applied Successfully!\033[0m"
            ;;
        "Exit"|"")
            clear
            exit 0
            ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."; echo
    # Loop back to menu
    clear
    continue
    break
    done
