#!/bin/bash
# GitHub.com/PiercingXX

# Define colors
yellow='\033[1;33m'
green='\033[0;32m'
blue='\033[0;34m'

nc='\033[0m'


# Add a safe clear that works even if TERM is unknown
safe_clear() {
    if command -v tput >/dev/null 2>&1 && [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ] && tput clear >/dev/null 2>&1; then
        clear
    else
        printf '\033c'
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect distro (used by update branches and helpers)
detect_distro() {
    if [ -r /etc/os-release ]; then
        . /etc/os-release
        DISTRO="${ID,,}"
    else
        DISTRO=""
    fi
}
detect_distro

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


ensure_jq() {
    if command_exists jq; then
        return 0
    fi
    echo -e "${yellow}jq is required for script auto-update. Attempting to install...${nc}"
    if [[ "$DISTRO" == "fedora" ]]; then
        sudo dnf -y install jq && return 0
    elif [[ "$DISTRO" == "arch" ]]; then
        # Try install without refreshing DB first, then with -Sy as fallback
        sudo pacman -S --needed --noconfirm jq && return 0 || sudo pacman -Sy --needed --noconfirm jq && return 0
    elif [[ "$DISTRO" == "debian" || "$DISTRO" == "ubuntu" || "$DISTRO" == "pop" || "$DISTRO" == "linuxmint" || "$DISTRO" == "mint" || "$DISTRO" == "pureos" ]]; then
        sudo apt update && sudo apt -y install jq && return 0
    fi
    echo -e "${yellow}Could not auto-install jq on this distro; continuing without auto-update of ~/.scripts.${nc}"
    return 1
}

# Ask for sudo password up front and keep sudo alive
sudo -v
# Keep-alive: update existing sudo time stamp until script finishes
( while true; do sudo -n true; sleep 60; done ) &
sudo_keepalive_pid=$!
trap 'kill "$sudo_keepalive_pid" 2>/dev/null' EXIT


# Ensure user can force shutdown and reboot without password
for cmd in /sbin/shutdown /sbin/reboot /usr/sbin/shutdown /usr/sbin/reboot; do
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
# Update Neovim plugins
    if command_exists nvim; then
        nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
    fi
# Update fwupd
    if command_exists fwupdmgr; then
        echo -e "${yellow}Updating firmware (fwupdmgr)...${nc}"
        sudo fwupdmgr refresh || true
        sudo fwupdmgr get-updates || true
        sudo fwupdmgr update -y || true
    fi
    echo -e "${yellow}Be Patient...${nc}"
# Update npm
    if command_exists npm; then
        sudo npm update -g --silent --no-progress
    fi
# Update cargo
    if command_exists cargo; then
        echo -e "${yellow}Updating cargo...${nc}"
        if cargo install-update --version >/dev/null 2>&1; then
            cargo install-update -a
        else
            cargo install cargo-update
            cargo install-update -a
        fi
    fi
# Update flatpak (user and system)
    if command_exists flatpak; then
        echo -e "${yellow}Updating flatpak (user)...${nc}"
        flatpak update --user -y || true
        flatpak uninstall --unused --user -y || true
        echo -e "${yellow}Updating flatpak (system)...${nc}"
        sudo flatpak update -y || true
        sudo flatpak uninstall --unused -y || true
    fi
# Update Docker images
    if command_exists docker; then
        echo -e "${yellow}Updating Docker images...${nc}"
        docker system prune -af --volumes
        mapfile -t images < <(docker images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>')
        echo -e "${yellow}Updating ${#images[@]} Docker image(s)...${nc}"
        for img in "${images[@]}"; do
            echo -e "  • ${img}"
            docker pull "$img" 2>/dev/null
        done
    fi
# Update yazi && its plugins
    if command_exists yazi; then
        echo -e "${yellow}Updating yazi...${nc}"
        if command_exists ya; then
            ya pkg upgrade || true
            YAZI_CONFIG="$HOME/.config/yazi/package.toml"
            if [ -f "$YAZI_CONFIG" ]; then
                mapfile -t desired_plugins < <(grep '^use = ' "$YAZI_CONFIG" | sed -E "s/use = \"(.*)\"/\1/" | sort)
                mapfile -t installed_plugins < <(ya pkg list | awk '{print $1}' | sort)
                for plugin in "${desired_plugins[@]}"; do
                    if ! printf '%s\n' "${installed_plugins[@]}" | grep -qx "$plugin"; then
                        echo -e "${yellow}Adding missing yazi plugin: $plugin${nc}"
                        ya pkg add "$plugin" || true
                    fi
                done
            fi
        fi
    fi
# Update Homebrew (brew)
    if command_exists brew; then
        echo -e "${yellow}Updating Homebrew (brew)...${nc}"
        brew update && brew upgrade
    fi
# Update pip
    if command_exists pip; then
        echo -e "${yellow}Updating system pip...${nc}"
        sudo pip install --upgrade pip --break-system-packages 2>/dev/null || true
    elif command_exists pip3; then
        echo -e "${yellow}Updating system pip3...${nc}"
        sudo pip3 install --upgrade pip --break-system-packages 2>/dev/null || true
    fi
# Update Hyprland if running
    if pgrep -x "Hyprland" > /dev/null; then
        echo -e "${yellow}Updating Hyprland packages...${nc}"
        hyprpm update
        hyprpm reload
    fi
}

# Function to git pull all repos in /media/Working-Storage/GitHub
git_pull_all_github_repos() {
    if ! command_exists git; then
        return
    fi
    # Allow override, then fall back to common locations
    local base_dir="${PX_GITHUB_DIR:-/media/Working-Storage/GitHub}"
    if [ ! -d "$base_dir" ]; then
        for alt in "$HOME/GitHub" "$HOME/Projects" "$HOME/Workspace" "$HOME/src"; do
            if [ -d "$alt" ]; then
                base_dir="$alt"
                break
            fi
        done
    fi
    if [ ! -d "$base_dir" ]; then
        # Only show warning if running interactively
        if [ -t 1 ]; then
            echo -e "${yellow}GitHub directory not found. Set PX_GITHUB_DIR to override.${nc}"
        fi
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


echo -e "${green}Starting system update...${nc}\n"
    ensure_jq
    update_bashrc
    auto_update_scripts
    git_pull_all_github_repos

if [[ "$DISTRO" == "arch" ]]; then
    # Prefer paru, then yay, then pacman
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
elif [[ "$DISTRO" == "debian" || "$DISTRO" == "ubuntu" || "$DISTRO" == "pop" || "$DISTRO" == "linuxmint" || "$DISTRO" == "mint" || "$DISTRO" == "pureos" ]]; then
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

if command_exists notify-send; then
    notify-send "System Update" "System update completed successfully!"
fi
echo -e "${green}System Updated Successfully!${nc}"
kill "$sudo_keepalive_pid" 2>/dev/null
