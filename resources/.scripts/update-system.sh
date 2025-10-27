#!/bin/bash
# GitHub.com/PiercingXX

# Define colors
yellow='\033[1;33m'
green='\033[0;32m'
blue='\033[0;34m'
nc='\033[0m'

# Ensure user can force shutdown and reboot without password
for cmd in /sbin/shutdown /sbin/reboot; do
    if ! sudo grep -q "$USER ALL=NOPASSWD: $cmd" /etc/sudoers; then
        echo "$USER ALL=NOPASSWD: $cmd" | sudo tee -a /etc/sudoers > /dev/null
    fi
done

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
        if cargo install-update --version >/dev/null 2>&1; then
            cargo install-update -a
        else
            cargo install cargo-update
            cargo install-update -a
        fi
    fi
    if command_exists fwupd; then
        fwupd refresh && fwupd update
    fi
    if command_exists flatpak; then
        flatpak update -y
        flatpak uninstall --unused -y
    fi
    nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
    if command_exists docker; then
        docker system prune -af --volumes
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

system_clean() {
    echo -e "${blue}Cleaning up system...${nc}"
    case "$DISTRO" in
        arch)
            # Remove orphaned packages and clean cache
            if command_exists paru; then
                paru -Qtdq | xargs -r paru -Rns --
            elif command_exists yay; then
                yay -Qtdq | xargs -r yay -Rns --
            else
                sudo pacman -Qtdq | xargs -r sudo pacman -Rns --
            fi
            sudo pacman -Sc --noconfirm
            ;;
        fedora)
            sudo dnf autoremove -y
            sudo dnf clean all
            ;;
        debian|ubuntu|pop|linuxmint|mint)
            sudo apt autoremove -y
            sudo apt clean
            ;;
        *)
            echo -e "${yellow}No cleaning steps defined for $DISTRO.${nc}"
            ;;
    esac
    # Clean Snaps
    if command_exists snap; then
        sudo snap set system refresh.retain=2
        # Remove all disabled snaps
        mapfile -t snap_args < <(snap list --all | awk '/disabled/{print $1, $2}' | while read -r snapname version; do printf '%q ' "$snapname" --revision="$version"; done)
        if [ "${#snap_args[@]}" -gt 0 ]; then
            sudo snap remove --purge "${snap_args[@]}"
        fi
    fi
    # Silently clean user cache
    rm -rf ~/.cache/* 2>/dev/null
    echo -e "${green}System cleaning complete!${nc}"
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
        system_clean
    elif command_exists yay; then
        yay -Syu --noconfirm
        universal_update
        system_clean
    else
        sudo pacman -Syu --noconfirm
        universal_update
        system_clean
    fi
elif [[ "$DISTRO" == "fedora" ]]; then
    sudo dnf update -y
    universal_update
    system_clean
elif [[ "$DISTRO" == "debian" || "$DISTRO" == "ubuntu" || "$DISTRO" == "pop" || "$DISTRO" == "linuxmint" || "$DISTRO" == "mint" ]]; then
    sudo apt update && sudo apt upgrade -y || true
    sudo apt full-upgrade -y
    sudo apt install -f
    sudo dpkg --configure -a
    sudo apt --fix-broken install -y
    sudo apt autoremove -y
    sudo apt update && sudo apt upgrade -y || true
    universal_update
    system_clean
    if command_exists snap; then
        sudo snap refresh
    fi
fi
echo -e "${green}System Updated Successfully!${nc}"
read -n 1 -s -r -p "Press any key to continue..."; echo
