#!/bin/bash
# Unified Maintenance Script for Arch, Fedora, Debian
# GitHub.com/PiercingXX

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "Cannot detect distribution!"
    exit 1
fi

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

username=$(id -u -n 1000)
builddir=$(pwd)

# Function to display a message box
msg_box() {
    whiptail --msgbox "$1" 0 0 0
}

# Distro-specific menu
case "$DISTRO" in
    arch)
        menu() {
            whiptail --backtitle "GitHub.com/PiercingXX" --title "Main Menu" \
                --menu "Run Options In Order:" 0 0 0 \
                "Update System"         "Update System" \
                "Update Mirrors"        "Update Mirrors" \
                "PiercingXX Rice"       "Gnome Piercing Rice (Distro Agnostic)" \
                "Piercing Gimp Only"    "Piercing Gimp Presets (Distro Agnostic)" \
                "Rice-No Hyprland"      "Piercing Rice w/o Hyprdots but still Hypr Keybinds" \
                "Reboot System"         "Reboot the system" \
                "Exit"                  "Exit the script" 3>&1 1>&2 2>&3
        }
        ;;
    fedora)
        menu() {
            whiptail --backtitle "GitHub.com/PiercingXX" --title "Main Menu" \
                --menu "Run Options In Order:" 0 0 0 \
                "Update System"         "Update System" \
                "PiercingXX Rice"       "Gnome Piercing Rice (Distro Agnostic)" \
                "Piercing Gimp Only"    "Piercing Gimp Presets (Distro Agnostic)" \
                "Reboot System"         "Reboot the system" \
                "Exit"                  "Exit the script" 3>&1 1>&2 2>&3
        }
        ;;
    debian|ubuntu|pop)
        menu() {
            whiptail --backtitle "GitHub.com/PiercingXX" --title "Main Menu" \
                --menu "Run Options In Order:" 0 0 0 \
                "Update System"         "Update System" \
                "PiercingXX Rice"       "Gnome Piercing Rice (Distro Agnostic)" \
                "Piercing Gimp Only"    "Piercing Gimp Presets (Distro Agnostic)" \
                "Reboot System"         "Reboot the system" \
                "Exit"                  "Exit the script" 3>&1 1>&2 2>&3
        }
        ;;
    *)
        echo "Unsupported distribution: $DISTRO"
        exit 1
        ;;
esac

# Main menu loop
while true; do
    clear
    echo -e "${BLUE}PiercingXX's Maintenance Script for $DISTRO${NC}"
    echo -e "${GREEN}Hello Handsome${NC}\n"
    choice=$(menu)
    case $choice in
        "Update System")
            echo -e "${YELLOW}Updating System...${NC}"
            # Cache sudo credentials
                sudo -v
            # Applies to all distros
                # Neovim Lazy Update
                    if command_exists nvim; then    
                    nvim --headless "+Lazy! sync" +qa
                    fi
                # Function to update pip if it exists
                    update_pip() {
                        if command_exists pip; then
                            echo -e "${YELLOW}Updating system pip...${NC}"
                            pip install --upgrade pip
                        elif command_exists pip3; then
                            echo -e "${YELLOW}Updating system pip3...${NC}"
                            pip3 install --upgrade pip
                        else
                            echo -e "${RED}pip not found.${NC}"
                        fi
                    }
                # Update global npm packages
                    if command_exists npm; then
                        sudo npm update -g
                    fi
                # Update Rust crates
                    if command_exists cargo; then
                        cargo install --list | awk '/^.*:/{print $1}' | xargs -r cargo install
                    fi
                # Update firmware
                    if command_exists fwupd; then
                        fwupd refresh && fwupd update
                    fi
                # Update all installed Docker images
                    if command_exists docker; then
                    update_docker_images() {
                        mapfile -t images < <(docker images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>')
                        echo -e "${YELLOW}Updating ${#images[@]} Docker image(s)...${NC}"
                        for img in "${images[@]}"; do
                            echo -e "  • ${img}"
                            docker pull "$img" 2>/dev/null
                        done
                        echo -e "${GREEN}Docker images updated.${NC}"
                    }
                    fi
            # Distro-specific updates
            if [[ "$DISTRO" == "arch" ]]; then
                if command_exists paru; then
                    paru -Syu --noconfirm
                else
                    sudo pacman -Syu --noconfirm
                fi
                wait
                if command_exists flatpak; then
                    flatpak update -y
                fi
                wait
                if pgrep -x "Hyprland" > /dev/null; then
                    hyprpm update
                    wait
                    hyprpm reload
                fi
            elif [[ "$DISTRO" == "fedora" ]]; then
                sudo dnf update -y && sudo dnf upgrade -y
                wait
                sudo dnf autoremove -y
                if command_exists flatpak; then
                    flatpak update -y
                fi
                wait
                if pgrep -x "Hyprland" > /dev/null; then
                    hyprpm update
                    wait
                    hyprpm reload
                fi
            elif [[ "$DISTRO" == "debian" || "$DISTRO" == "ubuntu" || "$DISTRO" == "pop" ]]; then
                sudo apt update && sudo apt upgrade -y || true
                wait
                sudo apt full-upgrade -y
                wait
                sudo apt install -f
                wait
                sudo dpkg --configure -a
                sudo apt --fix-broken install -y
                wait
                sudo apt autoremove -y
                sudo apt update && sudo apt upgrade -y || true
                wait
                if command_exists flatpak; then
                    flatpak update -y
                fi
                wait
                if pgrep -x "Hyprland" > /dev/null; then
                hyprpm update
                wait
                hyprpm reload
                fi
            fi
            echo -e "${GREEN}System Updated Successfully!${NC}"
            ;;
        "Update Mirrors")
            if [[ "$DISTRO" == "arch" ]]; then
                echo -e "${YELLOW}Updating Mirrors...${NC}"
                if ! command_exists reflector; then
                    sudo pacman -S reflector --noconfirm
                fi
                sudo reflector --verbose --sort rate -l 75 --save /etc/pacman.d/mirrorlist
                echo -e "${GREEN}Mirrors Updated${NC}"
            fi
            ;;
        "PiercingXX Rice")
            echo -e "${YELLOW}Downloading and Applying PiercingXX Rice...${NC}"
            rm -rf piercing-dots
            git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git
            chmod -R u+x piercing-dots
            cd piercing-dots || exit
            ./install.sh
            cd "$builddir" || exit
            rm -rf piercing-dots
            echo -e "${GREEN}PiercingXX Rice Applied Successfully!${NC}"
            ;;
        "Piercing Gimp Only")
            echo -e "${YELLOW}Installing Piercing Gimp Presets...${NC}"
            rm -rf piercing-dots
            git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git
            chmod -R u+x piercing-dots
            cd piercing-dots/scripts || exit
            ./gimp-mod.sh
            cd "$builddir" || exit
            rm -rf piercing-dots
            echo -e "${GREEN}Piercing Gimp Presets Installed Successfully!${NC}"
            ;;
        "Rice-No Hyprland")
            if [[ "$DISTRO" == "arch" ]]; then
                echo -e "${YELLOW}Downloading and Applying PiercingXX Rice w/o Hyprdots...${NC}"
                rm -rf piercing-dots
                git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git
                chmod -R u+x piercing-dots
                cd piercing-dots || exit
                cp -p dots/hypr/hyprland/keybinds.conf /home/"$username"/.config/hypr/hyprland/
                rm -rf dots/hypr
                ./install.sh
                cd "$builddir" || exit
                rm -rf piercing-dots
                echo -e "${GREEN}PiercingXX Rice Applied Successfully!${NC}"
            fi
            ;;
        "Reboot System")
            echo -e "${YELLOW}Rebooting system in 3 seconds...${NC}"
            sleep 2
            reboot
            ;;
        "Exit")
            clear
            echo -e "${BLUE}Thank You Handsome!${NC}"
            exit 0
            ;;
    esac
    while true; do
        read -p "Press [Enter] to continue..." 
        break
    done
done