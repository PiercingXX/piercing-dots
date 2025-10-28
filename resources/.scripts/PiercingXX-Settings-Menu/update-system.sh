#!/bin/bash
# GitHub.com/PiercingXX

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

clear
# Require internet before continuing
if ! check_internet; then
    echo "Internet connectivity is required to continue."
    exit 1
fi

# Ask for sudo password up front and keep sudo alive
sudo -v
# Function to start/refresh the sudo keep-alive process
start_sudo_keepalive() {
    # If a previous keep-alive is running, kill it
    if [[ -n "$sudo_keepalive_pid" ]] && kill -0 "$sudo_keepalive_pid" 2>/dev/null; then
        kill "$sudo_keepalive_pid" 2>/dev/null
    fi
    # Start a new keep-alive process with a shorter interval
    ( while true; do sudo -n true; sleep 20; done ) &
    sudo_keepalive_pid=$!
}

# Start the keep-alive process
start_sudo_keepalive
# Ensure the keep-alive process is killed on script exit
trap 'kill $sudo_keepalive_pid 2>/dev/null' EXIT

# Optionally, restart keep-alive if it dies (run in background)
( while true; do
    if ! kill -0 "$sudo_keepalive_pid" 2>/dev/null; then
        start_sudo_keepalive
    fi
    sleep 5
done ) &


# Ensure user can force shutdown and reboot without password
for cmd in /sbin/shutdown /sbin/reboot; do
    sudo -n true 2>/dev/null || { echo "Sudo session expired. Please re-run the script."; exit 1; }
    if ! sudo grep -q "$USER ALL=NOPASSWD: $cmd" /etc/sudoers; then
        echo "$USER ALL=NOPASSWD: $cmd" | sudo tee -a /etc/sudoers > /dev/null
    fi
done

# Unified function to update all scripts in ~/.scripts from GitHub repo, recursively handling subfolders
auto_update_scripts() {
    local GITHUB_REPO="Piercingxx/piercing-dots"
    local REMOTE_PATH="resources/.scripts"
    local LOCAL_DIR="$HOME/.scripts"

    # Ensure local scripts directory exists
    sudo -n true 2>/dev/null || { echo "Sudo session expired. Please re-run the script."; exit 1; }
    mkdir -p "$LOCAL_DIR"

    # Recursively fetch all files and folders from the GitHub API
    fetch_and_sync() {
        local api_path="$1"
        local local_path="$2"
        local api_url="https://api.github.com/repos/$GITHUB_REPO/contents/$api_path"
        local items
        items=$(curl -s "$api_url")
        echo "$items" | jq -c '.[]' | while read -r item; do
            local type name path download_url
            type=$(echo "$item" | jq -r '.type')
            name=$(echo "$item" | jq -r '.name')
            path=$(echo "$item" | jq -r '.path')
            download_url=$(echo "$item" | jq -r '.download_url')
            if [[ "$type" == "dir" ]]; then
                mkdir -p "$local_path/$name"
                fetch_and_sync "$path" "$local_path/$name"
            elif [[ "$type" == "file" ]]; then
                local tmp_file
                tmp_file=$(mktemp)
                if ! curl -fsSL "$download_url" -o "$tmp_file"; then
                    echo -e "${yellow}Failed to download $path from GitHub.${nc}"
                    rm -f "$tmp_file"
                    continue
                fi
                if [ ! -f "$local_path/$name" ] || ! cmp -s "$local_path/$name" "$tmp_file"; then
                    cp "$tmp_file" "$local_path/$name"
                    chmod +x "$local_path/$name"
                    echo -e "${green}Updated $path${nc}"
                fi
                rm -f "$tmp_file"
            fi
        done
    }

    fetch_and_sync "$REMOTE_PATH" "$LOCAL_DIR"
    echo -e "${green}You Good!${nc}"
}

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "Cannot detect distribution!"
    exit 1
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
        sudo -n true 2>/dev/null || { echo "Sudo session expired. Please re-run the script."; exit 1; }
        sudo pip install --upgrade pip --break-system-packages 2>/dev/null || true
    elif command_exists pip3; then
        echo -e "${yellow}Updating system pip3...${nc}"
        sudo -n true 2>/dev/null || { echo "Sudo session expired. Please re-run the script."; exit 1; }
        sudo pip3 install --upgrade pip --break-system-packages 2>/dev/null || true
    fi
    if command_exists npm; then
        sudo -n true 2>/dev/null || { echo "Sudo session expired. Please re-run the script."; exit 1; }
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
            sudo -n true 2>/dev/null || { echo "Sudo session expired. Please re-run the script."; exit 1; }
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
            sudo -n true 2>/dev/null || { echo "Sudo session expired. Please re-run the script."; exit 1; }
            sudo dnf autoremove -y
            sudo dnf clean all
            ;;
        debian|ubuntu|pop|linuxmint|mint)
            sudo -n true 2>/dev/null || { echo "Sudo session expired. Please re-run the script."; exit 1; }
            sudo apt autoremove -y
            sudo apt clean
            ;;
        *)
            echo -e "${yellow}No cleaning steps defined for $DISTRO.${nc}"
            ;;
    esac
    # Clean Snaps
    if command_exists snap; then
        sudo -n true 2>/dev/null || { echo "Sudo session expired. Please re-run the script."; exit 1; }
        sudo snap set system refresh.retain=2
        # Remove all disabled snaps
        mapfile -t snap_args < <(snap list --all | awk '/disabled/{print $1, $2}' | while read -r snapname version; do printf "%q " "$snapname" --revision="$version"; done)
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
notify-send "System Update" "System update completed successfully!"
echo -e "${green}System Updated Successfully!${nc}"
# Kill the sudo keep-alive background process (handled by trap)