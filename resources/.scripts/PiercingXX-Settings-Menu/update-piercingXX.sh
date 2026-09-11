#!/bin/bash
# GitHub.com/PiercingXX

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

pretty_name() {
    if [ ! -f /etc/os-release ]; then
        echo "Cannot detect distribution!"
        return 1
    fi
    . /etc/os-release
    DISTRO_NAME="${ID^}"
    DISTRO_VERSION="${VERSION_ID:-}"
    NEW_PRETTY_NAME="PiercingXX $DISTRO_NAME $DISTRO_VERSION"
    sudo cp /etc/os-release /etc/os-release.bak
    sudo sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"$NEW_PRETTY_NAME\"/" /etc/os-release
    echo "PRETTY_NAME set to \"$NEW_PRETTY_NAME\" in /etc/os-release"
}

resolve_username() {
    if [ -n "${SUDO_USER:-}" ] && getent passwd "$SUDO_USER" >/dev/null 2>&1; then
        echo "$SUDO_USER"
        return
    fi
    local owner
    owner="$(stat -c '%U' "$(pwd)" 2>/dev/null || true)"
    if [ -n "$owner" ] && getent passwd "$owner" >/dev/null 2>&1; then
        echo "$owner"
        return
    fi
    local u1000
    u1000="$(getent passwd 1000 | cut -d: -f1)"
    if [ -n "$u1000" ]; then
        echo "$u1000"
        return
    fi
    id -un
}

install_gum_if_needed() {
    command_exists gum && return 0
    echo "gum not found. Installing..."
    if command_exists pacman; then
        sudo pacman -S --noconfirm gum
    elif command_exists apt; then
        export DEBIAN_FRONTEND=noninteractive
        sudo -E apt update && sudo -E apt install -y gum
    elif command_exists dnf; then
        sudo dnf install -y gum
    elif command_exists xbps-install; then
        sudo xbps-install -Sy gum
    else
        echo "Please install gum manually."
        exit 1
    fi
}

clone_rice() {
    rm -rf "$CLONE_DIR"
    git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git "$CLONE_DIR"
    chmod -R u+x "$CLONE_DIR"
}

cleanup_clone() {
    cd "$builddir" || true
    rm -rf "$CLONE_DIR"
}

# Check for active network connection
if command_exists nmcli; then
    state=$(nmcli -t -f STATE g)
    if [[ "$state" != connected ]]; then
        echo "Network connectivity is required to continue."
        exit 1
    fi
else
    if ! ip -4 addr show | grep -q "inet "; then
        echo "Network connectivity is required to continue."
        exit 1
    fi
fi
if ! ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
    echo "Network connectivity is required to continue."
    exit 1
fi

install_gum_if_needed

username="$(resolve_username)"
home_dir="$(getent passwd "$username" | cut -d: -f6)"
[ -z "$home_dir" ] && home_dir="$HOME"
builddir=$(pwd)
CLONE_DIR="$builddir/piercing-dots"
trap cleanup_clone EXIT

while true; do
    clear
    choice=$(printf "%s\n" \
        "Apply PiercingXX - Everything" \
        "Apply PiercingXX - Gimp Only" \
        "Apply PiercingXX - without Hyprland configs" \
        "Apply PiercingXX - Gnome Customizations ONLY" \
        "Exit" | \
        gum choose --header "PiercingXX Update Options" --cursor.foreground 212 --selected.foreground 212)
    case $choice in
        "Apply PiercingXX - Everything")
            echo -e "\033[1;33mDownloading and Applying PiercingXX Rice...\033[0m"
            clone_rice
            (cd "$CLONE_DIR" && ./install.sh)
            cleanup_clone
            echo -e "\033[0;32mPiercingXX Rice Applied Successfully!\033[0m"
            ;;
        "Apply PiercingXX - Gimp Only")
            echo -e "\033[1;33mInstalling PiercingXX - Gimp Presets...\033[0m"
            clone_rice
            (cd "$CLONE_DIR/scripts" && ./gimp-mod.sh)
            cleanup_clone
            echo -e "\033[0;32mPiercing Gimp Presets Installed Successfully!\033[0m"
            ;;
        "Apply PiercingXX - without Hyprland configs")
            echo -e "\033[1;33mDownloading and Applying PiercingXX Rice w/o Hyprdots...\033[0m"
            clone_rice
            mkdir -p "$home_dir/.config/hypr/hyprland"
            # Preserve current keybinds before wiping hypr from the rice copy
            if [ -f "$CLONE_DIR/dots/hypr/hyprland/keybinds.lua" ]; then
                cp -pf "$CLONE_DIR/dots/hypr/hyprland/keybinds.lua" "$home_dir/.config/hypr/hyprland/"
            fi
            rm -rf "$CLONE_DIR/dots/hypr"
            (cd "$CLONE_DIR" && ./install.sh)
            cleanup_clone
            echo -e "\033[0;32mPiercingXX Rice Applied Successfully!\033[0m"
            ;;
        "Apply PiercingXX - Gnome Customizations ONLY")
            echo -e "\033[1;33mApplying PiercingXX - Gnome Customizations ONLY...\033[0m"
            clone_rice
            (cd "$CLONE_DIR/scripts" && chmod u+x gnome-customizations.sh && ./gnome-customizations.sh)
            cleanup_clone
            ;;
        "Exit"|"")
            clear
            exit 0
            ;;
    esac
done
