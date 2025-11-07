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

# Require internet before continuing
if ! check_internet; then
    echo "Internet connectivity is required to continue."
    exit 1
fi

# Ask for sudo password up front and keep sudo alive
sudo -v
# Keep-alive: update existing sudo time stamp until script finishes
( while true; do sudo -n true; sleep 60; done ) &
sudo_keepalive_pid=$!


# Ensure user can force shutdown and reboot without password
for cmd in /sbin/shutdown /sbin/reboot; do
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
        # Upgrade yazi core packages
        ya pkg upgrade
        # Check and sync yazi plugins from package.toml
        YAZI_CONFIG="$HOME/.config/yazi/package.toml"
        if [ -f "$YAZI_CONFIG" ]; then
            # Get list of plugins from package.toml
            mapfile -t desired_plugins < <(grep '^use = ' "$YAZI_CONFIG" | sed -E "s/use = \"(.*)\"/\1/" | sort)
            # Get currently installed plugins
            mapfile -t installed_plugins < <(ya pkg list | awk '{print $1}' | sort)
            # Add missing plugins
            for plugin in "${desired_plugins[@]}"; do
                if ! printf '%s\n' "${installed_plugins[@]}" | grep -qx "$plugin"; then
                    echo -e "${yellow}Adding missing yazi plugin: $plugin${nc}"
                    ya pkg add "$plugin"
                fi
            done
        fi
    fi
    if pgrep -x "Hyprland" > /dev/null; then
        hyprpm update
        hyprpm reload
    fi
}

# Function to git pull all repos in /media/Working-Storage/GitHub
git_pull_all_github_repos() {
    if ! command_exists git; then
        return
    fi
    local base_dir="/media/Working-Storage/GitHub"
    if [ ! -d "$base_dir" ]; then
        echo -e "${yellow}GitHub directory not found: $base_dir${nc}"
        return
    fi
    echo -e "${blue}Updating all GitHub repositories in $base_dir...${nc}"
    for repo in "$base_dir"/*; do
        if [ -d "$repo/.git" ]; then
            echo -e "${green}Updating $(basename "$repo")...${nc}"
            (cd "$repo" && git pull --ff-only)
        fi
    done
    echo -e "${green}All GitHub repositories updated!${nc}"
}


clear
echo -e "${blue}PiercingXX System Update${nc}"
echo -e "${green}Checking for script updates...${nc}"
auto_update_scripts "$@"
echo -e "${green}Starting system update...${nc}\n"
update_bashrc
git_pull_all_github_repos
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
notify-send "System Update" "System update completed successfully!"
echo -e "${green}System Updated Successfully!${nc}"
kill $sudo_keepalive_pid