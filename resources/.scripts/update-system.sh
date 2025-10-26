#!/bin/bash
# GitHub.com/PiercingXX

# Ensure user can force shutdown and reboot without password
for cmd in /sbin/shutdown /sbin/reboot; do
    if ! sudo grep -q "$USER ALL=NOPASSWD: $cmd" /etc/sudoers; then
        echo "$USER ALL=NOPASSWD: $cmd" | sudo tee -a /etc/sudoers > /dev/null
    fi
done

# Unified function to update all scripts in ~/.scripts from GitHub repo
auto_update_scripts() {
    local GITHUB_REPO="Piercingxx/piercing-dots"
    local REMOTE_PATH="resources/.scripts"
    local LOCAL_DIR="$HOME/.scripts"

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
            echo -e "${yellow}Failed to download $script from GitHub.${nc}"
            rm -f "$TMP_FILE"
            continue
        fi
        # Only replace if different or missing
        if [ ! -f "$LOCAL_DIR/$script" ] || ! cmp -s "$LOCAL_DIR/$script" "$TMP_FILE"; then
            cp "$TMP_FILE" "$LOCAL_DIR/$script"
            chmod +x "$LOCAL_DIR/$script"
            echo -e "${green}Updated $script${nc}"
        fi
        rm -f "$TMP_FILE"
    done

    echo -e "${green}All scripts checked and updated if needed!${nc}"
}

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "Cannot detect distribution!"
    exit 1
fi

# Define colors
yellow='\033[1;33m'
green='\033[0;32m'
blue='\033[0;34m'
nc='\033[0m'

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Update .bashrc from GitHub
update_bashrc() {
    local REMOTE_URL="https://raw.githubusercontent.com/Piercingxx/piercing-dots/main/resources/bash/.bashrc"
    local TMP_FILE
    TMP_FILE=$(mktemp)
    if ! curl -fsSL "$REMOTE_URL" -o "$TMP_FILE"; then
        echo -e "${yellow}Failed to download .bashrc from GitHub.${nc}"
        rm -f "$TMP_FILE"
        return 1
    fi
    if ! cmp -s "$HOME/.bashrc" "$TMP_FILE"; then
        cp "$TMP_FILE" "$HOME/.bashrc"
        echo -e "${green}.bashrc has been updated.${nc}"
    fi
    rm -f "$TMP_FILE"
    return 0
}

# Universal update logic
universal_update() {
    if command_exists pip; then
        echo -e "${yellow}Updating system pip...${nc}"
        sudo pip install --upgrade pip --break-system-packages 2>/dev/null || true
    elif command_exists pip3; then
        echo -e "${yellow}Updating system pip3...${nc}"
        sudo pip3 install --upgrade pip --break-system-packages 2>/dev/null || true
    fi
    if command_exists npm; then
        sudo npm update -g --silent --no-progress
    fi
    if command_exists cargo; then
        cargo install --list | awk '/^.*:/{print $1}' | xargs -r cargo install
    fi
    if command_exists fwupd; then
        fwupd refresh && fwupd update
    fi
    if command_exists flatpak; then
        flatpak update -y
    fi
    nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
    if command_exists docker; then
        mapfile -t images < <(docker images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>')
        echo -e "${yellow}Updating ${#images[@]} Docker image(s)...${nc}"
        for img in "${images[@]}"; do
            echo -e "  • ${img}"
            docker pull "$img" 2>/dev/null
        done
    fi
    if command_exists yazi; then
        ya pkg upgrade
    fi
    if pgrep -x "Hyprland" > /dev/null; then
        hyprpm update
        hyprpm reload
    fi
}

# Main logic
echo -e "${blue}PiercingXX System Update${nc}"
echo -e "${green}Starting system update...${nc}\n"
clear
echo -e "${blue}PiercingXX System Update${nc}"
echo -e "${green}Checking for script updates...${nc}"
auto_update_scripts "$@"
echo -e "${green}Starting system update...${nc}\n"
update_bashrc
if [[ "$DISTRO" == "arch" ]]; then
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
    sudo dnf update -y
    sudo dnf autoremove -y
    universal_update
elif [[ "$DISTRO" == "debian" || "$DISTRO" == "ubuntu" || "$DISTRO" == "pop" || "$DISTRO" == "linuxmint" || "$DISTRO" == "mint" ]]; then
    sudo apt update && sudo apt upgrade -y || true
    sudo apt full-upgrade -y
    sudo apt install -f
    sudo dpkg --configure -a
    sudo apt --fix-broken install -y
    sudo apt autoremove -y
    sudo apt update && sudo apt upgrade -y || true
    universal_update
    if command_exists snap; then
        sudo snap refresh
    fi
fi
echo -e "${green}System Updated Successfully!${nc}"
read -n 1 -s -r -p "Press any key to continue..."; echo
