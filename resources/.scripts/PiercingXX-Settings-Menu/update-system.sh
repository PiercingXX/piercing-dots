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

# Ensure jq is available (auto-install on Debian/Ubuntu/Mint and Fedora)
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
    elif [[ "$DISTRO" == "debian" || "$DISTRO" == "ubuntu" || "$DISTRO" == "pop" || "$DISTRO" == "linuxmint" || "$DISTRO" == "mint" ]]; then
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
# Update Neovim plugins
    nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
# Update fwupd
    if command_exists fwupd; then
        echo -e "${yellow}Updating fwupd...${nc}"
        fwupd refresh && fwupdmgr get-updates && fwupd update
    fi
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
# Update flatpak
    if command_exists flatpak; then
        echo -e "${yellow}Updating flatpak...${nc}"
        flatpak update -y
        flatpak uninstall --unused -y
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
    local base_dir="/media/Working-Storage/GitHub"
    if [ ! -d "$base_dir" ]; then
        # Only show warning if running interactively
        if [ -t 1 ]; then
            echo -e "${yellow}GitHub directory not found: $base_dir${nc}"
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


clear
echo -e "${blue}PiercingXX System Update${nc}"
echo -e "${green}Checking for script updates...${nc}"
if ensure_jq; then
    auto_update_scripts "$@"
else
    echo -e "${yellow}Skipping script auto-update because jq is not available.${nc}"
fi
echo -e "${green}Starting system update...${nc}\n"
update_bashrc
git_pull_all_github_repos
if [[ "$DISTRO" == "arch" ]]; then
    # --- Arch-specific helpers to handle common pacman conflicts (e.g., node-gyp) ---
    arch_backup_unowned_under() {
        # Usage: arch_backup_unowned_under <base_dir> <tag>
        local base="$1" tag="$2"
        if [ -z "$base" ] || [ ! -d "$base" ]; then
            return 1
        fi
        local ts backup_root moved_count=0
        ts=$(date +%Y%m%d-%H%M%S)
        backup_root="/var/tmp/pacman-conflicts-${tag:-node-modules}-$ts"
        echo -e "${yellow}[${tag}] Scanning for unowned files under $base...${nc}"
        mapfile -t all_files < <(find "$base" -type f 2>/dev/null)
        if [ ${#all_files[@]} -eq 0 ]; then
            echo -e "${yellow}[${tag}] No files found; skipping.${nc}"
            return 1
        fi
        local -a unowned_files=()
        for f in "${all_files[@]}"; do
            if ! pacman -Qo "$f" >/dev/null 2>&1; then
                unowned_files+=("$f")
            fi
        done
        if [ ${#unowned_files[@]} -eq 0 ]; then
            echo -e "${yellow}[${tag}] All files owned by packages; nothing to clean.${nc}"
            return 1
        fi
        echo -e "${yellow}[${tag}] Backing up ${#unowned_files[@]} unowned file(s) to ${backup_root}...${nc}"
        sudo mkdir -p "$backup_root"
        for f in "${unowned_files[@]}"; do
            local dest="$backup_root$f"
            sudo mkdir -p "$(dirname "$dest")"
            sudo mv "$f" "$dest" && moved_count=$((moved_count+1))
        done
        sudo find "$base" -type d -empty -delete || true
        echo -e "${green}[${tag}] Cleaned ${moved_count} file(s). Backup at ${backup_root}${nc}"
        return 0
    }

    arch_detect_and_fix_node_gyp_conflicts() {
        # Backwards-compatible wrapper for node-gyp specific case
        local base="/usr/lib/node_modules/node-gyp/node_modules"
        [ -d "$base" ] || return 1
        arch_backup_unowned_under "$base" "node-gyp"
    }

    arch_handle_node_modules_conflicts_from_log() {
        # Usage: arch_handle_node_modules_conflicts_from_log <logfile>
        local log="$1"
        [ -f "$log" ] || return 1
        # Extract unique roots like /usr/lib/node_modules/<pkg>
        mapfile -t roots < <(grep -E "^.+: /usr/lib/node_modules/[^/]+/" "$log" | \
            sed -E 's|^[^:]+: (/usr/lib/node_modules/[^/]+).*|\1|' | sort -u)
        if [ ${#roots[@]} -eq 0 ]; then
            return 1
        fi
        local cleaned_any=1
        for root in "${roots[@]}"; do
            local pkg
            pkg=$(basename "$root")
            # Prefer cleaning the node_modules subtree if present; else the root itself
            if [ -d "$root/node_modules" ]; then
                if arch_backup_unowned_under "$root/node_modules" "$pkg"; then
                    cleaned_any=0
                fi
            else
                if arch_backup_unowned_under "$root" "$pkg"; then
                    cleaned_any=0
                fi
            fi
        done
        return $cleaned_any
    }

    arch_run_upgrade_with_retry() {
        local tool="$1"; shift || true
        local cmd log tmp_status
        if [ "$tool" = "paru" ]; then
            cmd=(paru -Syu --noconfirm "$@")
        elif [ "$tool" = "yay" ]; then
            cmd=(yay -Syu --noconfirm "$@")
        else
            cmd=(sudo pacman -Syu --noconfirm "$@")
        fi
        log=$(mktemp)
        echo -e "${blue}[upgrade] Starting system upgrade via $tool...${nc}"
        if ! ( "${cmd[@]}" 2>&1 | tee "$log" ); then
            tmp_status=$?
            if grep -q "failed to commit transaction (conflicting files)" "$log" && grep -q "/usr/lib/node_modules/" "$log"; then
                echo -e "${yellow}[upgrade] Detected node_modules conflicting files during $tool upgrade.${nc}"
                if arch_handle_node_modules_conflicts_from_log "$log"; then
                    echo -e "${yellow}[upgrade] Retrying after node_modules cleanup...${nc}"
                    if ( "${cmd[@]}" 2>&1 | tee "$log" ); then
                        rm -f "$log"
                        return 0
                    fi
                fi
                echo -e "${yellow}[upgrade] Cleanup insufficient; retrying with targeted --overwrite for affected node_modules paths...${nc}"
                # Build targeted overwrite args for each root
                mapfile -t roots < <(grep -E "^.+: /usr/lib/node_modules/[^/]+/" "$log" | \
                    sed -E 's|^[^:]+: (/usr/lib/node_modules/[^/]+).*|\1|' | sort -u)
                local -a overwrite_args=()
                for root in "${roots[@]}"; do
                    if [ -d "$root/node_modules" ]; then
                        overwrite_args+=(--overwrite "$root/node_modules/*")
                    else
                        overwrite_args+=(--overwrite "$root/*")
                    fi
                done
                if [ "$tool" = "paru" ] || [ "$tool" = "yay" ]; then
                    cmd=("$tool" -Syu --noconfirm "${overwrite_args[@]}")
                else
                    cmd=(sudo pacman -Syu --noconfirm "${overwrite_args[@]}")
                fi
                if ( "${cmd[@]}" 2>&1 | tee "$log" ); then
                    echo -e "${green}[upgrade] Successful after targeted overwrite.${nc}"
                    rm -f "$log"
                    return 0
                fi
                echo -e "${yellow}[upgrade] Targeted overwrite failed; manual intervention required.${nc}"
            fi
            rm -f "$log"
            return "$tmp_status"
        fi
        rm -f "$log"
        return 0
    }

    # Proactive cleanup before attempting upgrade if node-gyp version will change
    if pacman -Qi node-gyp >/dev/null 2>&1 && pacman -Si node-gyp >/dev/null 2>&1; then
        current_ver=$(pacman -Qi node-gyp | awk '/Version/{print $3}')
        repo_ver=$(pacman -Si node-gyp | awk '/Version/{print $3}')
        if [ "$current_ver" != "$repo_ver" ]; then
            if arch_detect_and_fix_node_gyp_conflicts; then
                echo -e "${green}[node-gyp] Proactive cleanup done (version change ${current_ver} -> ${repo_ver}).${nc}"
            fi
        fi
    fi

    # Prefer paru, then yay, then pacman
    if command_exists paru; then
        arch_run_upgrade_with_retry paru || true
        universal_update
    elif command_exists yay; then
        arch_run_upgrade_with_retry yay || true
        universal_update
    else
        arch_run_upgrade_with_retry pacman || true
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
 
# Post-update: verify Node tooling and optionally clean old backups
verify_node_tooling() {
    local ok=0
    if command_exists node; then
        echo -e "${green}node: $(node -v)${nc}" || true
    else
        echo -e "${yellow}node not found in PATH${nc}"; ok=1
    fi
    if command_exists npm; then
        echo -e "${green}npm: $(npm -v)${nc}" || true
        echo -e "Global npm root: $(npm root -g 2>/dev/null)" || true
    else
        echo -e "${yellow}npm not found in PATH${nc}"; ok=1
    fi
    if command_exists node-gyp; then
        echo -e "${green}node-gyp: $(node-gyp --version 2>/dev/null)${nc}" || true
    else
        echo -e "${yellow}node-gyp not found in PATH${nc}"; ok=1
    fi
    return $ok
}

cleanup_old_conflict_backups() {
    # Skip if user opts out
    if [ -n "$PX_UPDATE_KEEP_CONFLICT_BACKUPS" ]; then
        echo -e "${yellow}Skipping cleanup of conflict backups (PX_UPDATE_KEEP_CONFLICT_BACKUPS set).${nc}"
        return 0
    fi
    # Remove conflict backups older than 14 days; cover both old and generalized patterns
    echo -e "${yellow}Pruning conflict backups in /var/tmp older than 14 days...${nc}"
    sudo find /var/tmp -maxdepth 1 -type d \( -name 'pacman-conflicts-node-gyp-*' -o -name 'pacman-conflicts-*' \) -mtime +14 -print -exec rm -rf {} + || true
}

if verify_node_tooling; then
    cleanup_old_conflict_backups
fi
notify-send "System Update" "System update completed successfully!"
echo -e "${green}System Updated Successfully!${nc}"
kill $sudo_keepalive_pid
