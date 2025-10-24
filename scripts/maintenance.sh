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

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure user can force shutdown without password
if ! sudo grep -q "$USER ALL=NOPASSWD: /sbin/shutdown" /etc/sudoers; then
    echo "$USER ALL=NOPASSWD: /sbin/shutdown" | sudo tee -a /etc/sudoers > /dev/null
fi

# Reliable-ish internet check:
# 1) Prefer nm-online or networkctl if available (fast readiness)
# 2) Try HTTP(S) endpoints that return 204 or fixed text (detects DNS + HTTP + captive portals)
# 3) Fallback to ICMP ping to public IPs (in case HTTP is blocked)
check_internet() {
    local timeout=4
    if command_exists nm-online; then
        nm-online -q -t "$timeout" && return 0
    fi
    if command_exists networkctl; then
        networkctl -q is-online --timeout="$timeout" && return 0
    fi
    local urls=(
        "https://connectivitycheck.gstatic.com/generate_204"    # 204 when open internet
        "http://www.google.com/generate_204"                    # 204 when open internet
        "http://www.msftncsi.com/ncsi.txt"                      # 200 + 'Microsoft NCSI'
        "http://www.msftconnecttest.com/connecttest.txt"        # 200 + 'Microsoft Connect Test'
    )
    for url in "${urls[@]}"; do
        local code
        code=$(curl -4 -fsS --max-time "$timeout" -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || true)
        if [[ "$code" == "204" ]]; then
            return 0
        fi
        if [[ "$code" == "200" && "$url" == *"msft"* ]]; then
            local body
            body=$(curl -4 -fsS --max-time "$timeout" "$url" 2>/dev/null | tr -d '\r\n')
            if [[ "$body" == "Microsoft NCSI" || "$body" == "Microsoft Connect Test" ]]; then
                return 0
            fi
        fi
    done
    local hosts=(1.1.1.1 8.8.8.8 9.9.9.9)
    for host in "${hosts[@]}"; do
        if ping -4 -c 1 -W 1 "$host" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

# Require internet before continuing
if ! check_internet; then
    echo "Internet connectivity is required to continue."
    exit 1
fi


# Auto-install rsync if missing
if ! command_exists rsync; then
    echo -e "${YELLOW}rsync not found – attempting install...${NC}"
    case "$DISTRO" in
        arch)
            sudo pacman -S --noconfirm rsync ;;
        fedora)
            sudo dnf install -y rsync >/dev/null 2>&1 ;;
        debian|ubuntu|pop|linuxmint|mint)
            sudo apt install -y rsync >/dev/null 2>&1 ;;
        *)
            echo -e "${YELLOW}Unsupported distro for auto rsync install. Skipping.${NC}"
            ;;
    esac
    if command_exists rsync; then
        echo -e "${GREEN}rsync installed successfully.${NC}"
    else
        echo -e "${YELLOW}Could not install rsync; will full replace config.${NC}"
    fi
fi

# Function to update local .bashrc from Piercing‑dots GitHub
update_bashrc() {
    local REMOTE_URL="https://raw.githubusercontent.com/Piercingxx/piercing-dots/main/resources/bash/.bashrc"
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
        cp "$TMP_FILE" "$HOME/.bashrc"
        echo -e "${GREEN}.bashrc has been updated.${NC}"
    fi
    rm -f "$TMP_FILE"
    return 0
}


# Unified function to update all scripts in ~/.scripts from GitHub repo
auto_update_scripts() {
    local GITHUB_REPO="Piercingxx/piercing-dots"
    local REMOTE_PATH="resources/.scripts"
    local LOCAL_DIR="$HOME/.scripts"
    local MAINTENANCE_SCRIPT="maintenance.sh"
    local MAINTENANCE_UPDATED=0

    # Ensure local scripts directory exists
    mkdir -p "$LOCAL_DIR"

    # Get list of scripts from GitHub (requires 'jq')
    local SCRIPTS
    SCRIPTS=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/contents/$REMOTE_PATH" | jq -r '.[] | select(.type=="file") | .name')

    for script in $SCRIPTS; do
        local RAW_URL="https://raw.githubusercontent.com/$GITHUB_REPO/main/$REMOTE_PATH/$script"
        local TMP_FILE
        TMP_FILE=$(mktemp)
        if ! curl -fsSL "$RAW_URL" -o "$TMP_FILE"; then
            echo -e "${RED}Failed to download $script from GitHub.${NC}"
            rm -f "$TMP_FILE"
            continue
        fi
        # Only replace if different
        if ! cmp -s "$LOCAL_DIR/$script" "$TMP_FILE"; then
            cp "$TMP_FILE" "$LOCAL_DIR/$script"
            chmod +x "$LOCAL_DIR/$script"
            echo "Updated $script"
            # If maintenance.sh was updated, set flag
            if [[ "$script" == "$MAINTENANCE_SCRIPT" ]]; then
                MAINTENANCE_UPDATED=1
            fi
        fi
        rm -f "$TMP_FILE"
    done

    if [[ $MAINTENANCE_UPDATED -eq 1 ]]; then
        exec "$LOCAL_DIR/$MAINTENANCE_SCRIPT" "--resume-update" "$@"
    fi

    echo "All scripts are up to date!"
}






# Function to update universal stuff
    universal_update() {
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
        # Update Neovim
            nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
        # Update_docker_images
            if command_exists docker; then
                mapfile -t images < <(docker images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>')
                echo -e "${YELLOW}Updating ${#images[@]} Docker image(s)...${NC}"
                for img in "${images[@]}"; do
                    echo -e "  • ${img}"
                    docker pull "$img" 2>/dev/null
                done
            fi
        # Yazi Update
            if command_exists yazi; then
                ya pkg upgrade
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
    echo -e "${GREEN}H3ll0${NC}\n"
    choice=$(menu)
    case $choice in
        "Update System")
            echo -e "${YELLOW}Updating System...${NC}"
            # PiercingXX Maintenance.sh update check
                # Skip auto‑update if we are resuming
                if [[ "$RESUME_UPDATE" -eq 0 ]]; then
                    auto_update_scripts "$@"
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
            exit 0
            ;;
    esac
    while true; do
        read -p "Press [Enter] to continue..." 
        break
    done
done