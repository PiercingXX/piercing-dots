#!/bin/bash
# Update System Script (split from maintenance.sh)

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

# Reliable-ish internet check
check_internet() {
    local timeout=4
    if command_exists nm-online; then
        nm-online -q -t "$timeout" && return 0
    fi
    if command_exists networkctl; then
        networkctl -q is-online --timeout="$timeout" && return 0
    fi
    local urls=(
        "https://connectivitycheck.gstatic.com/generate_204"
        "http://www.google.com/generate_204"
        "http://www.msftncsi.com/ncsi.txt"
        "http://www.msftconnecttest.com/connecttest.txt"
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
    echo -e "${yellow}rsync not found – attempting install...${nc}"
    case "$DISTRO" in
        arch)
            sudo pacman -S --noconfirm rsync ;;
        fedora)
            sudo dnf install -y rsync >/dev/null 2>&1 ;;
        debian|ubuntu|pop|linuxmint|mint)
            sudo apt install -y rsync >/dev/null 2>&1 ;;
        *)
            echo -e "${yellow}Unsupported distro for auto rsync install. Skipping.${nc}"
            ;;
    esac
    if command_exists rsync; then
        echo -e "${green}rsync installed successfully.${nc}"
    else
        echo -e "${yellow}Could not install rsync; will full replace config.${nc}"
    fi
fi

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
clear
echo -e "${blue}PiercingXX System Update${nc}"
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
