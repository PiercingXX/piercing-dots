#!/bin/bash
# GitHub.com/PiercingXX

# Define colors
yellow='\033[1;33m'
green='\033[0;32m'
blue='\033[0;34m'

nc='\033[0m'

if [[ -d "$HOME/.cargo/bin" && ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
    PATH="$HOME/.cargo/bin:$PATH"
fi


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

service_is_active_any() {
    local svc

    if command_exists systemctl; then
        for svc in "$@"; do
            if systemctl is-active --quiet "$svc" 2>/dev/null; then
                return 0
            fi
        done
    fi

    if command_exists sv; then
        for svc in "$@"; do
            if sv status "$svc" 2>/dev/null | grep -q '^run:'; then
                return 0
            fi
        done
    fi

    return 1
}

npm_updates_use_system_prefix() {
    local npm_prefix

    npm_prefix=$(npm config get prefix 2>/dev/null || true)
    [[ "$npm_prefix" == "/usr" || "$npm_prefix" == "/usr/local" || -z "$npm_prefix" || "$npm_prefix" == "undefined" ]]
}

fwupd_has_updatable_devices() {
    local fwupd_output="$1"

    if [[ -z "$fwupd_output" ]]; then
        return 1
    fi

    if grep -q '^No updatable devices$' <<< "$fwupd_output"; then
        return 1
    fi

    if grep -qE '(^[[:space:]]*• )|(^[[:space:]]*[0-9]+ device\(s\) can be updated$)' <<< "$fwupd_output"; then
        return 0
    fi

    return 1
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
    elif [[ "$DISTRO" == "debian" || "$DISTRO" == "ubuntu" || "$DISTRO" == "pop" || "$DISTRO" == "linuxmint" || "$DISTRO" == "mint" || "$DISTRO" == "pureos" || "$DISTRO" == "droidian" || "$DISTRO" == "mobian" || "$DISTRO" == "ubuntutouch" || "$DISTRO" == "raspbian" ]]; then
        sudo apt update && sudo apt -y install jq && return 0
    elif [[ "$DISTRO" == "void" ]]; then
        sudo xbps-install -Sy jq && return 0
    fi
    echo -e "${yellow}Could not auto-install jq on this distro; continuing without auto-update of ~/.scripts.${nc}"
    return 1
}

# Ask for sudo password up front and keep sudo alive
sudo -v
# Keep-alive: update existing sudo time stamp until script finishes
( while true; do sudo -n true; sleep 300; done ) &
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
    local monitor_rel="${REMOTE_PATH}/Control-Scripts/launch-server-monitor.sh"
    local running_script
    running_script=$(readlink -f "${0}" 2>/dev/null || echo "${0}")

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
                
                # Special handling for launch-server-monitor.sh to preserve user's REMOTE line
                local tmp_compare="$tmp_file"
                if [[ "$path" == "$monitor_rel" && -f "$local_path/$name" ]]; then
                    local saved_remote_line
                    saved_remote_line=$(grep -E '^REMOTE=' "$local_path/$name" || true)
                    if [[ -n "$saved_remote_line" ]]; then
                        # Apply the saved REMOTE line to the temp file for comparison
                        tmp_compare=$(mktemp)
                        awk -v saved="$saved_remote_line" 'BEGIN{replaced=0} {if(!replaced && $0 ~ /^REMOTE=/){print saved; replaced=1; next} {print}} END{if(!replaced && saved!="") print saved}' "$tmp_file" > "$tmp_compare"
                    fi
                fi
                
                # Compare using the potentially modified temp file
                if [ ! -f "$local_path/$name" ] || ! cmp -s "$local_path/$name" "$tmp_compare"; then
                    local target_file
                    target_file="$local_path/$name"
                    # Avoid overwriting the currently running script mid-execution.
                    if [[ "$(readlink -f "$target_file" 2>/dev/null || echo "$target_file")" == "$running_script" ]]; then
                        cp "$tmp_file" "${target_file}.upstream"
                        chmod +x "${target_file}.upstream" 2>/dev/null || true
                        echo -e "${yellow}Update available for running script; saved as:${nc} ${target_file}.upstream"
                        echo -e "${yellow}Restart the script to apply it (or replace the file manually).${nc}"
                        rm -f "$tmp_file"
                        if [[ "$tmp_compare" != "$tmp_file" ]]; then
                            rm -f "$tmp_compare"
                        fi
                        continue
                    fi

                    cp "$tmp_file" "$target_file"
                    
                    # Re-apply the saved REMOTE line to the installed file
                    if [[ "$path" == "$monitor_rel" && -f "$local_path/$name" ]]; then
                        local saved_remote_line
                        saved_remote_line=$(grep -E '^REMOTE=' "$local_path/$name" 2>/dev/null || echo "REMOTE=\"dr3k@server-debian-ai\"")
                        local tmp_preserve
                        tmp_preserve=$(mktemp)
                        awk -v saved="$saved_remote_line" 'BEGIN{replaced=0} {if(!replaced && $0 ~ /^REMOTE=/){print saved; replaced=1; next} {print}} END{if(!replaced && saved!="") print saved}' "$local_path/$name" > "$tmp_preserve" && mv "$tmp_preserve" "$local_path/$name"
                    fi
                    
                    chmod +x "$local_path/$name"
                    echo -e "${green}Updated $path${nc}"
                fi
                
                # Clean up temp files
                rm -f "$tmp_file"
                if [[ "$tmp_compare" != "$tmp_file" ]]; then
                    rm -f "$tmp_compare"
                fi
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


# Keep Synology Drive client updated on Debian/Ubuntu by pulling the current installer
update_synology_drive() {
    if ! command_exists dpkg || ! command_exists apt; then
        return
    fi
    local version="4.0.1-17885"
    local build="${version##*-}"
    local base_url="https://global.download.synology.com/download/Utility/SynologyDriveClient/${version}/Ubuntu/Installer"
    local pkg="synology-drive-client-${build}.x86_64.deb"
    local installed
    installed=$(dpkg-query -W -f='${Version}' synology-drive-client 2>/dev/null || true)
    if [ "$installed" = "$version" ]; then
        return
    fi
    local tmp_pkg
    tmp_pkg=$(mktemp)
    if curl -fsSL "${base_url}/${pkg}" -o "$tmp_pkg"; then
        sudo dpkg -i "$tmp_pkg" || sudo apt --fix-broken install -y
    else
        echo -e "${yellow}Synology Drive download failed; keeping existing version.${nc}"
    fi
    rm -f "$tmp_pkg"
}


# Rebuild Hyprland stack on Debian/Ubuntu directly from upstream repos
update_hyprland_builds() {
    if ! command_exists hyprland; then
        return
    fi
    case "$DISTRO" in
        debian|ubuntu) ;;
        *) return ;;
    esac
    if ! command_exists git || ! command_exists cmake; then
        echo -e "${yellow}Git/CMake missing; skipping Hyprland rebuild.${nc}"
        return
    fi

    local workdir
    workdir=$(mktemp -d) || return
    trap 'rm -rf "$workdir"' RETURN

    # Version pins — updated for compatibility and features
    local hyprutils_version="v0.2.4"
    local hyprlang_version="v0.6.7"
    local hyprland_protocols_version="v0.7.0"
    local hyprwayland_scanner_version="v0.4.5"
    local hyprlock_version="v0.5.1"
    local hypridle_version="v0.3.1"
    local hyprgraphics_version="v0.2.0"
    local hyprpaper_version="v0.7.6"
    local aquamarine_version="v0.4.0"
    local hyprcursor_version="v0.1.8"
    local hyprland_version="v0.55.3"

    local jobs
    jobs=$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF || echo 2)

    build_cmake() {
        local name=$1 repo=$2 ref=$3
        echo -e "${yellow}Updating ${name} (${ref})...${nc}"
        rm -rf "${workdir:?}/${name}" 2>/dev/null || true
        if git clone --depth 1 --recursive -b "$ref" "$repo" "$workdir/${name}"; then
            ( cd "$workdir/${name}" && \
                cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE=Release -S . -B build && \
                cmake --build build --config Release -j"$jobs" && \
                sudo cmake --install build >/dev/null 2>&1 ) || {
                echo -e "${yellow}${name} build failed; leaving existing install.${nc}"
            }
        else
            echo -e "${yellow}${name} download failed; skipping.${nc}"
        fi
    }

    build_protocols() {
        echo -e "${yellow}Updating hyprland-protocols (${hyprland_protocols_version})...${nc}"
        rm -rf "$workdir/hyprland-protocols" 2>/dev/null || true
        if git clone --depth 1 --recursive -b "$hyprland_protocols_version" https://github.com/hyprwm/hyprland-protocols.git "$workdir/hyprland-protocols"; then
            sudo mkdir -p /usr/share/wayland-protocols
            sudo cp -r "$workdir/hyprland-protocols"/protocols/* /usr/share/wayland-protocols/ 2>/dev/null || true
        else
            echo -e "${yellow}hyprland-protocols download failed; skipping.${nc}"
        fi
    }

    build_cmake "hyprutils" https://github.com/hyprwm/hyprutils.git "$hyprutils_version"
    build_cmake "hyprlang" https://github.com/hyprwm/hyprlang.git "$hyprlang_version"
    build_protocols
    build_cmake "hyprwayland-scanner" https://github.com/hyprwm/hyprwayland-scanner.git "$hyprwayland_scanner_version"
    build_cmake "hyprlock" https://github.com/hyprwm/hyprlock.git "$hyprlock_version"
    build_cmake "hypridle" https://github.com/hyprwm/hypridle.git "$hypridle_version"
    build_cmake "hyprgraphics" https://github.com/hyprwm/hyprgraphics.git "$hyprgraphics_version"
    build_cmake "hyprpaper" https://github.com/hyprwm/hyprpaper.git "$hyprpaper_version"
    build_cmake "aquamarine" https://github.com/hyprwm/aquamarine.git "$aquamarine_version"
    build_cmake "hyprcursor" https://github.com/hyprwm/hyprcursor.git "$hyprcursor_version"
    build_cmake "Hyprland" https://github.com/hyprwm/Hyprland.git "$hyprland_version"
}


# Universal update logic
universal_update() {
# Update Neovim plugins
    if command_exists nvim; then
        nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
    fi
# Update fwupd
    if command_exists fwupdmgr; then
        local fwupd_updates_output
        echo -e "${yellow}Updating firmware (fwupdmgr)...${nc}"
        sudo fwupdmgr refresh 2>/dev/null || true
        fwupd_updates_output=$(sudo fwupdmgr get-updates 2>&1 || true)
        if [[ -n "$fwupd_updates_output" ]]; then
            printf '%s\n' "$fwupd_updates_output"
            if fwupd_has_updatable_devices "$fwupd_updates_output"; then
                sudo fwupdmgr update -y || true
            fi
        fi
    fi
# Update Synology Drive (Debian/Ubuntu installs)
    update_synology_drive
    echo -e "${yellow}Be Patient...${nc}"
# Update npm
    if command_exists npm; then
        if [[ "$DISTRO" == "arch" || "$DISTRO" == "void" ]]; then
            # On package-managed distros, global npm updates under /usr often create package-manager file conflicts.
            if npm_updates_use_system_prefix; then
                echo -e "${yellow}Skipping global npm update on $DISTRO because npm is using a system prefix.${nc}"
                echo -e "${yellow}Tip: set npm prefix to a user dir (e.g. ~/.local) for global installs.${nc}"
            else
                npm update -g --silent --no-progress || true
            fi
        else
            sudo npm update -g --silent --no-progress || true
        fi
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
            YAZI_CONFIG_DIR="$HOME/.config/yazi"
            YAZI_CONFIG="$YAZI_CONFIG_DIR/package.toml"
            # Fix common package.toml issues before upgrade
            if [ -f "$YAZI_CONFIG" ]; then
                sed -i -e 's/system-clipboard\.yazi/system-clipboard-yazi/g' "$YAZI_CONFIG" || true
            fi
            # Skip upgrade if legacy header exists to avoid parse abort
            if [ -f "$YAZI_CONFIG" ] && grep -q '^\[\[plugin\.deps\]\]' "$YAZI_CONFIG"; then
                echo -e "${yellow}Yazi package.toml has legacy [[plugin.deps]]; skipping 'ya pkg upgrade'.${nc}"
            else
                ya pkg upgrade || true
            fi
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
# Update pip
    if command_exists pip; then
        echo -e "${yellow}Updating system pip...${nc}"
        sudo pip install --upgrade pip --break-system-packages 2>/dev/null || true
    elif command_exists pip3; then
        echo -e "${yellow}Updating system pip3...${nc}"
        sudo pip3 install --upgrade pip --break-system-packages 2>/dev/null || true
    fi
# Update Homebrew (brew)
    if command_exists brew; then
        echo -e "${yellow}Updating Homebrew (brew)...${nc}"
        brew update && brew upgrade
    fi
# Update ClamAV virus definitions
    if command_exists freshclam; then
        echo -e "${yellow}Updating ClamAV virus definitions...${nc}"
        # Check active service managers to avoid freshclam lock conflicts.
        if service_is_active_any clamav-freshclam.service clamav-freshclam freshclam; then
            echo -e "${yellow}ClamAV freshclam service is running; skipping manual update.${nc}"
        else
            sudo freshclam || true
        fi
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

# Handle common Arch file conflict fixes
arch_fix_node_gyp_conflicts() {
    local pm="$1"
    echo -e "${yellow}Attempting node-gyp overwrite fix...${nc}"
    case "$pm" in
        paru|yay)
            "$pm" -S --noconfirm --overwrite '/usr/lib/node_modules/node-gyp/node_modules/*' node-gyp || true
            ;;
        pacman)
            sudo pacman -S --noconfirm --overwrite '/usr/lib/node_modules/node-gyp/node_modules/*' node-gyp || true
            ;;
    esac
}

# Handle Arch pacman-style "failed to commit transaction (conflicting files)" issues.
# Typical cause: files created by `npm -g` or other manual installs living under /usr.
# Strategy: detect the conflicting paths from the upgrade log, then *move* unowned
# paths aside into a timestamped backup dir and retry the upgrade.
arch_extract_conflict_paths() {
    local log_file="$1"
    # Output: one absolute path per line
    # Lines look like: "npm: /usr/lib/node_modules/npm/... exists in filesystem"
    awk 'match($0, /^[^:]+: (\/[^ ]+) exists in filesystem$/, m) {print m[1]}' "$log_file" | sort -u
}

arch_fix_pacman_conflicting_files() {
    local log_file="$1"
    local -a paths=()
    local p
    while IFS= read -r p; do
        [[ -n "$p" ]] && paths+=("$p")
    done < <(arch_extract_conflict_paths "$log_file")

    if (( ${#paths[@]} == 0 )); then
        return 1
    fi

    echo -e "${yellow}Detected pacman file conflicts:${nc}"
    for p in "${paths[@]}"; do
        echo " - $p"
    done

    if [ ! -t 0 ]; then
        echo -e "${yellow}Non-interactive shell detected; not modifying filesystem automatically.${nc}"
        echo "Tip: inspect ownership with: sudo pacman -Qo <path>"
        return 2
    fi

    local reply
    read -r -p "Move unowned conflicting files aside and retry upgrade? [Y/n] " reply
    reply=${reply:-Y}
    if [[ ! "$reply" =~ ^[Yy]$ ]]; then
        return 2
    fi

    local backup_root="/var/tmp/pacman-conflicts-$(date +%Y%m%d-%H%M%S)"
    sudo mkdir -p "$backup_root"

    local moved_any=0
    for p in "${paths[@]}"; do
        if ! sudo test -e "$p"; then
            continue
        fi

        local owner
        owner=$(sudo pacman -Qo "$p" 2>&1 || true)
        if echo "$owner" | grep -qi "No package owns"; then
            local dest_dir="$backup_root$(dirname "$p")"
            sudo mkdir -p "$dest_dir"
            sudo mv -f "$p" "$dest_dir/" && moved_any=1
        else
            echo -e "${yellow}Skipping owned path:${nc} $p"
            echo "  $owner"
        fi
    done

    if (( moved_any == 1 )); then
        echo -e "${green}Moved unowned conflicting files to:${nc} $backup_root"
        return 0
    fi

    echo -e "${yellow}No unowned conflicting paths were moved.${nc}"
    return 2
}

arch_run_upgrade_capture_log() {
    local pm="$1"
    local log_file="$2"

    # Ensure we can capture a failing exit code even with a tee pipeline.
    set -o pipefail

    case "$pm" in
        paru|yay)
            "$pm" -Syu --noconfirm 2>&1 | tee "$log_file"
            return ${PIPESTATUS[0]}
            ;;
        pacman)
            sudo pacman -Syu --noconfirm 2>&1 | tee "$log_file"
            return ${PIPESTATUS[0]}
            ;;
        *)
            echo "Unknown package manager: $pm" >&2
            return 2
            ;;
    esac
}

arch_log_needs_manual_conflict_resolution() {
    local log_file="$1"
    # paru/yay can detect "inner conflicts" (often AUR packages) and refuse to proceed with --noconfirm.
    grep -Eq "Inner conflicts found:|Conflicting packages will have to be confirmed manually|can not install conflicting packages with --noconfirm" "$log_file"
}

arch_run_upgrade_interactive_capture_log() {
    local pm="$1"
    local log_file="$2"

    set -o pipefail

    case "$pm" in
        paru|yay)
            "$pm" -Syu 2>&1 | tee "$log_file"
            return ${PIPESTATUS[0]}
            ;;
        pacman)
            sudo pacman -Syu 2>&1 | tee "$log_file"
            return ${PIPESTATUS[0]}
            ;;
        *)
            echo "Unknown package manager: $pm" >&2
            return 2
            ;;
    esac
}

arch_upgrade_with_conflict_repair() {
    local pm="$1"
    local log_file
    log_file=$(mktemp)

    if arch_run_upgrade_capture_log "$pm" "$log_file"; then
        rm -f "$log_file"
        return 0
    fi

    # Handle package conflicts that require manual confirmation (e.g. mutually-exclusive AUR packages).
    if arch_log_needs_manual_conflict_resolution "$log_file"; then
        echo -e "${yellow}Upgrade requires manual conflict resolution (cannot proceed with --noconfirm).${nc}"
        if [ ! -t 0 ]; then
            echo -e "${yellow}Non-interactive shell detected; cannot resolve package conflicts automatically.${nc}"
            echo -e "${yellow}Last upgrade log saved at:${nc} $log_file"
            return 1
        fi

        local reply
        read -r -p "Re-run upgrade interactively now (no --noconfirm)? [Y/n] " reply
        reply=${reply:-Y}
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            if arch_run_upgrade_interactive_capture_log "$pm" "$log_file"; then
                rm -f "$log_file"
                return 0
            fi
        fi
        # If interactive run did not succeed, keep going into other repair paths and finally return failure.
    fi

    if grep -q "failed to commit transaction (conflicting files)" "$log_file"; then
        echo -e "${yellow}Upgrade failed due to conflicting files; attempting automatic repair...${nc}"

        if arch_fix_pacman_conflicting_files "$log_file"; then
            # Retry full upgrade after moving conflicts aside
            if arch_run_upgrade_capture_log "$pm" "$log_file"; then
                rm -f "$log_file"
                return 0
            fi
        fi

        # Fallback: try legacy npm/node-gyp overwrite tricks (best-effort)
        echo -e "${yellow}Still failing; attempting npm/node-gyp overwrite fallback...${nc}"
        case "$pm" in
            paru|yay)
                "$pm" -S --noconfirm --overwrite '/usr/lib/node_modules/npm/*' npm || true
                "$pm" -S --noconfirm --overwrite '/usr/lib/node_modules/eslint/*' eslint || true
                ;;
            pacman)
                sudo pacman -S --noconfirm --overwrite '/usr/lib/node_modules/npm/*' npm || true
                sudo pacman -S --noconfirm --overwrite '/usr/lib/node_modules/eslint/*' eslint || true
                ;;
        esac
        arch_fix_node_gyp_conflicts "$pm"

        arch_run_upgrade_capture_log "$pm" "$log_file" || true

        # If we now hit manual package conflicts, offer an interactive run.
        if arch_log_needs_manual_conflict_resolution "$log_file"; then
            echo -e "${yellow}Upgrade now requires manual conflict resolution.${nc}"
            if [ -t 0 ]; then
                local reply
                read -r -p "Re-run upgrade interactively now (no --noconfirm)? [Y/n] " reply
                reply=${reply:-Y}
                if [[ "$reply" =~ ^[Yy]$ ]]; then
                    if arch_run_upgrade_interactive_capture_log "$pm" "$log_file"; then
                        rm -f "$log_file"
                        return 0
                    fi
                fi
            fi
        fi
    fi

    echo -e "${yellow}System upgrade did not complete successfully.${nc}"
    echo -e "${yellow}Last upgrade log saved at:${nc} $log_file"
    return 1
}

debian_fix_node_gyp_conflicts() {
    echo -e "${yellow}Attempting node-gyp reinstall fix (Debian/Ubuntu)...${nc}"
    sudo apt update || true
    sudo apt -y install --reinstall node-gyp npm || true
    sudo apt -y install --reinstall nodejs npm || true
}

fedora_fix_node_gyp_conflicts() {
    echo -e "${yellow}Attempting node-gyp reinstall fix (Fedora)...${nc}"
    sudo dnf -y reinstall nodejs npm node-gyp || true
    sudo dnf -y reinstall nodejs npm || true
}

debian_upgrade() {
    sudo apt update && sudo apt upgrade -y || true
    sudo apt full-upgrade -y || return 1
    sudo apt install -f || true
    sudo dpkg --configure -a || true
    sudo apt --fix-broken install -y || true
    sudo apt autoremove -y || true
    sudo apt update && sudo apt upgrade -y || true
}

fedora_upgrade() {
    sudo dnf -y upgrade || return 1
}

void_upgrade() {
    sudo xbps-install -Su || return 1
    sudo xbps-remove -Oo || true
}

if [[ "$DISTRO" == "arch" ]]; then
    # Check and rebuild paru if it has library dependency issues
    rebuild_paru_if_broken() {
        local cooldown_file="/var/tmp/paru-rebuild-skip"
        local cooldown_secs=86400

        # Skip if paru already works
        if command_exists paru && paru --version >/dev/null 2>&1; then
            return
        fi

        # Detect libalpm ABI mismatch to trigger rebuild immediately
        if command_exists paru; then
            local paru_err
            paru_err=$(paru --version >/dev/null 2>&1 || true)
            if echo "$paru_err" | grep -q "libalpm.so"; then
                echo -e "${yellow}paru is broken (libalpm ABI mismatch); rebuilding from AUR...${nc}"
            fi
        fi

        # Respect cooldown after a failed rebuild to avoid repeated breakage during upstream churn
        if [ -f "$cooldown_file" ]; then
            local now last
            now=$(date +%s)
            last=$(stat -c %Y "$cooldown_file" 2>/dev/null || echo 0)
            if [ $((now - last)) -lt $cooldown_secs ]; then
                echo -e "${yellow}Skipping paru rebuild (cooldown from previous failure).${nc}"
                return
            fi
        fi

        # Require build tooling
        if ! command_exists git || ! command_exists makepkg; then
            echo -e "${yellow}Skipping paru rebuild (missing git/makepkg).${nc}"
            return
        fi

        echo -e "${yellow}paru appears broken (library mismatch); rebuilding from AUR...${nc}"
        sudo pacman -R --noconfirm paru-bin >/dev/null 2>&1 || true
        local tmpdir
        tmpdir=$(mktemp -d)
        if git clone https://aur.archlinux.org/paru.git "$tmpdir/paru" 2>/dev/null; then
            if (cd "$tmpdir/paru" && makepkg -si --noconfirm); then
                rm -f "$cooldown_file"
            else
                echo -e "${yellow}paru rebuild failed; continuing with pacman only.${nc}"
                touch "$cooldown_file"
            fi
        else
            echo -e "${yellow}Failed to clone paru from AUR; continuing with pacman only.${nc}"
            touch "$cooldown_file"
        fi
        rm -rf "$tmpdir"
    }

    rebuild_paru_if_broken

    # Prefer paru, then yay, then pacman
    if command_exists paru && paru --version >/dev/null 2>&1; then
        if arch_upgrade_with_conflict_repair "paru"; then
            universal_update
        else
            echo -e "${yellow}Arch upgrade failed; skipping remaining update steps.${nc}"
            exit 1
        fi
    elif command_exists yay; then
        if arch_upgrade_with_conflict_repair "yay"; then
            universal_update
        else
            echo -e "${yellow}Arch upgrade failed; skipping remaining update steps.${nc}"
            exit 1
        fi
    else
        if arch_upgrade_with_conflict_repair "pacman"; then
            universal_update
        else
            echo -e "${yellow}Arch upgrade failed; skipping remaining update steps.${nc}"
            exit 1
        fi
    fi
elif [[ "$DISTRO" == "fedora" ]]; then
    fedora_upgrade || {
        echo -e "${yellow}dnf upgrade failed; attempting node-gyp fix...${nc}"
        fedora_fix_node_gyp_conflicts
        fedora_upgrade || true
    }
    universal_update
elif [[ "$DISTRO" == "debian" || "$DISTRO" == "ubuntu" || "$DISTRO" == "pop" || "$DISTRO" == "linuxmint" || "$DISTRO" == "mint" || "$DISTRO" == "pureos" || "$DISTRO" == "droidian" || "$DISTRO" == "mobian" || "$DISTRO" == "ubuntutouch" || "$DISTRO" == "raspbian" ]]; then
    debian_upgrade || {
        echo -e "${yellow}apt upgrade failed; attempting node-gyp fix...${nc}"
        debian_fix_node_gyp_conflicts
        debian_upgrade || true
    }
    universal_update
    update_hyprland_builds
    if command_exists snap; then
        sudo snap refresh
    fi
elif [[ "$DISTRO" == "void" ]]; then
    void_upgrade || {
        echo -e "${yellow}xbps upgrade failed; skipping remaining update steps.${nc}"
        exit 1
    }
    universal_update
fi

if command_exists notify-send; then
    notify-send "System Update" "System update completed successfully!"
fi
echo -e "${green}System Updated Successfully!${nc}"
kill "$sudo_keepalive_pid" 2>/dev/null
