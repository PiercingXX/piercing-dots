#!/bin/bash
# GitHub.com/PiercingXX

pretty_name() {
    if [ ! -f /etc/os-release ]; then
        echo "Cannot detect distribution!"
        return 1
    fi
    . /etc/os-release
    DISTRO_NAME="${ID^}"
    DISTRO_VERSION="${VERSION_ID:-}"
    NEW_PRETTY_NAME="PiercingXX $DISTRO_NAME $DISTRO_VERSION"
    sudo cp /etc/os-release /etc/os-release.bak
    sudo sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"$NEW_PRETTY_NAME\"/" /etc/os-release
    echo "PRETTY_NAME set to \"$NEW_PRETTY_NAME\" in /etc/os-release"
}

# Check for active network connection
    if command_exists nmcli; then
        state=$(nmcli -t -f STATE g)
        if [[ "$state" != connected ]]; then
            echo "Network connectivity is required to continue."
            exit 1
        fi
    else
        # Fallback: ensure at least one interface has an IPv4 address
        if ! ip -4 addr show | grep -q "inet "; then
            echo "Network connectivity is required to continue."
            exit 1
        fi
    fi
        # Additional ping test to confirm internet reachability
        if ! ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
            echo "Network connectivity is required to continue."
            exit 1
        fi

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
        "Apply PiercingXX - Everything" \
        "Apply PiercingXX - Gimp Only" \
        "Apply PiercingXX - without Hyprland configs" \
        "Apply PiercingXX - Gnome Customizations ONLY" \
        "Exit" | \
        gum choose --header "PiercingXX Update Options" --cursor.foreground 212 --selected.foreground 212)
    case $choice in
        "Apply PiercingXX - Everything")
            echo -e "\033[1;33mDownloading and Applying PiercingXX Rice...\033[0m"
            rm -rf piercing-dots
            git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git
            chmod -R u+x piercing-dots
            cd piercing-dots || exit
            ./install.sh
            rm -rf piercing-dots
            cd "$builddir" || exit
            echo -e "\033[0;32mPiercingXX Rice Applied Successfully!\033[0m"
            ;;
        "Apply PiercingXX - Gimp Only")
            echo -e "\033[1;33mInstalling PiercingXX - Gimp Presets...\033[0m"
            rm -rf piercing-dots
            git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git
            chmod -R u+x piercing-dots
            cd piercing-dots/scripts || exit
            ./gimp-mod.sh
            rm -rf piercing-dots
            cd "$builddir" || exit
            echo -e "\033[0;32mPiercing Gimp Presets Installed Successfully!\033[0m"
            ;;
        "Apply PiercingXX - without Hyprland configs")
            echo -e "\033[1;33mDownloading and Applying PiercingXX Rice w/o Hyprdots...\033[0m"
            rm -rf piercing-dots
            git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git
            chmod -R u+x piercing-dots
            cd piercing-dots || exit
            cp -pf dots/hypr/hyprland/keybinds.conf /home/"$username"/.config/hypr/hyprland/
            rm -rf dots/hypr
            ./install.sh
            rm -rf piercing-dots
            cd "$builddir" || exit
            echo -e "\033[0;32mPiercingXX Rice Applied Successfully!\033[0m"
            ;;
        "Apply PiercingXX - Gnome Customizations ONLY")
            echo -e "\033[1;33mApplying PiercingXX - Gnome Customizations ONLY...\033[0m"
            rm -rf piercing-dots
            git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git
            chmod -R u+x piercing-dots
            cd piercing-dots || exit
            cd scripts || exit
            chmod u+x gnome-customizations.sh
            ./gnome-customizations.sh
            rm -rf piercing-dots
            cd "$builddir" || exit
            ;;
        "Exit"|"")
            clear
            exit 0
            ;;
    esac
    # Loop back to menu
    clear
    continue
    break
    done