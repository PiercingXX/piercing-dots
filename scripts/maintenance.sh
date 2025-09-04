#!/bin/bash
# GitHub.com/PiercingXX

# Detect if we are resuming after an auto‑update
RESUME_UPDATE=0
if [[ "$1" == "--resume-update" ]]; then
    RESUME_UPDATE=1
    shift   # remove the flag so it doesn’t interfere with other arguments
fi

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

# Check if a command exists
    command_exists() {
        command -v "$1" >/dev/null 2>&1
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

# Auto‑update Maintenance.sh from PiercingXX GitHub
auto_update() {
    local GITHUB_RAW_URL="https://raw.githubusercontent.com/Piercingxx/piercing-dots/main/scripts/maintenance.sh"
    local TMP_FILE
    TMP_FILE=$(mktemp)
    # Download the latest script
    if ! curl -fsSL "$GITHUB_RAW_URL" -o "$TMP_FILE"; then
        echo -e "${RED}Failed to download update from GitHub.${NC}"
        rm -f "$TMP_FILE"
        return 1
    fi
    # If downloaded file differs from current one, copy to the home folder
    if ! cmp -s "$0" "$TMP_FILE"; then
        echo -e "${YELLOW}Updating maintenance script from GitHub...${NC}"
        local HOME_SCRIPT="$HOME/maintenance.sh"
        if ! cp "$TMP_FILE" "$HOME_SCRIPT"; then
            echo -e "${RED}Failed to copy the script to $HOME_SCRIPT. Check permissions.${NC}"
            rm -f "$TMP_FILE"
            return 1
        fi
        chmod +x "$HOME_SCRIPT"
        msg_box "Maintenance.sh was updated. Press [Enter] twice to proceed."
        # Re‑execute the updated script from the home folder with a flag
        exec "$HOME_SCRIPT" "--resume-update" "$@"
    fi
    # Clean up temporary file if no update was performed
    rm -f "$TMP_FILE"
    return 0
}

# Function to update local .bashrc from Piercing‑dots GitHub
update_bashrc() {
    local REMOTE_URL="https://raw.githubusercontent.com/Piercingxx/piercing-dots/main/.bashrc"
    local TMP_FILE
    TMP_FILE=$(mktemp)
    # Download the remote .bashrc
    if ! curl -fsSL "$REMOTE_URL" -o "$TMP_FILE"; then
        echo -e "${RED}Failed to download .bashrc from GitHub.${NC}"
        rm -f "$TMP_FILE"
        return 1
    fi
    # Compare with local .bashrc
    if ! cmp -s "$HOME/.bashrc" "$TMP_FILE"; then
        echo -e "${YELLOW}.bashrc differs from the GitHub version. Updating...${NC}"
        cp "$TMP_FILE" "$HOME/.bashrc"
        echo -e "${GREEN}.bashrc has been updated.${NC}"
    else
        echo -e "${GREEN}.bashrc is already up to date.${NC}"
    fi
    rm -f "$TMP_FILE"
    return 0
}

# Function to update universal stuff
    universal_update() {
        # Neovim Lazy Update
            if command_exists nvim; then    
                nvim --headless "+Lazy! sync" +qa
            fi
        # Update pip if it exists
            if command_exists pip; then
                echo -e "${YELLOW}Updating system pip...${NC}"
                sudo pip install --upgrade pip --break-system-packages 2>/dev/null || true
            elif command_exists pip3; then
                echo -e "${YELLOW}Updating system pip3...${NC}"
                sudo pip3 install --upgrade pip --break-system-packages 2>/dev/null || true
            fi
        # Update global npm packages
            if command_exists npm; then
                sudo npm update -g --silent --no-progress
            fi
        # Update Rust crates
            if command_exists cargo; then
                cargo install --list | awk '/^.*:/{print $1}' | xargs -r cargo install
            fi
        # Update firmware
            if command_exists fwupd; then
                fwupd refresh && fwupd update
            fi
        # Update Flatpak packages
            if command_exists flatpak; then
                flatpak update -y
            fi
        # Update_docker_images
            if command_exists docker; then
                mapfile -t images < <(docker images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>')
                echo -e "${YELLOW}Updating ${#images[@]} Docker image(s)...${NC}"
                for img in "${images[@]}"; do
                    echo -e "  • ${img}"
                    docker pull "$img" 2>/dev/null
                done
            fi
        # Hyprland update
            if pgrep -x "Hyprland" > /dev/null; then
                hyprpm update
                hyprpm reload
            fi
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
                "Rice-No Hyprland"      "Piercing Rice w/o Hyprdots but with Hypr Keybinds" \
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
    debian|ubuntu|pop|linuxmint)
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
            # PiercingXX Maintenance.sh update check
                # Skip auto‑update if we are resuming
                if [[ "$RESUME_UPDATE" -eq 0 ]]; then
                    auto_update "$@"
                fi
            # Update local .bashrc from Piercing‑dots GitHub
                update_bashrc
            # Distro-specific updates
                if [[ "$DISTRO" == "arch" ]]; then
                # Paru, Yay, or Pacman update
                    if command_exists paru; then
                        paru -Syu --noconfirm
                        universal_update
                    elif command_exists yay; then
                        yay -Syu --noconfirm
                        universal_update
                    else
                        sudo pacman -Syu --noconfirm
                        universal_update
                    fi
                elif [[ "$DISTRO" == "fedora" ]]; then
                # DNF update
                    sudo dnf update -y
                    sudo dnf autoremove -y
                    universal_update
                elif [[ "$DISTRO" == "debian" || "$DISTRO" == "ubuntu" || "$DISTRO" == "pop" || "$DISTRO" == "linuxmint" || "$DISTRO" == "mint" ]]; then
                    # APT update
                    sudo apt update && sudo apt upgrade -y || true
                    sudo apt full-upgrade -y
                    sudo apt install -f
                    sudo dpkg --configure -a
                    sudo apt --fix-broken install -y
                    sudo apt autoremove -y
                    sudo apt update && sudo apt upgrade -y || true
                    universal_update
                    # SNAP update
                    if command_exists snap; then
                        sudo snap refresh
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
            sudo reboot
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