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

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "Cannot detect distribution!"
    exit 1
fi

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
    mapfile -t snap_args < <(snap list --all | awk '/disabled/{print $1, $2}' | while read -r snapname version; do printf "%q " "$snapname" --revision="$version"; done)
    if [ "${#snap_args[@]}" -gt 0 ]; then
        sudo snap remove --purge "${snap_args[@]}"
    fi
fi
# Silently clean user cache
rm -rf ~/.cache/* 2>/dev/null
echo -e "${green}System cleaning complete!${nc}"

# Clean all temp files and empty trash for all users (no prompt)

# Remove system temp files
rm -rf /tmp/* /var/tmp/*

# Remove user cache and temp files
for userdir in /home/*; do
    if [ -d "$userdir" ]; then
        rm -rf "$userdir"/.cache/*
        rm -rf "$userdir"/Downloads/*
        # Empty trash (freedesktop spec)
        rm -rf "$userdir"/.local/share/Trash/files/*
        rm -rf "$userdir"/.local/share/Trash/info/*
    fi
done

# Also clean root's cache and trash if present
rm -rf /root/.cache/*
rm -rf /root/.local/share/Trash/files/*
rm -rf /root/.local/share/Trash/info/*

echo "System temp files and trash have been cleaned."
echo -e "${green}System cleaning complete!${nc}"