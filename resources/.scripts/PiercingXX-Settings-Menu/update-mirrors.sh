#!/bin/bash
# GitHub.com/PiercingXX

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
nc='\033[0m'

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Only for Arch
if [[ "$DISTRO" != "arch" ]]; then
    echo -e "${yellow}Mirror update is only supported on Arch Linux.${nc}"
    exit 0
fi

# Require reflector
if ! command_exists reflector; then
    echo -e "${yellow}Installing reflector...${nc}"
    sudo pacman -S reflector --noconfirm
fi

clear
echo -e "${green}Updating Mirrors...${nc}"
sudo reflector --verbose --sort rate -l 75 --save /etc/pacman.d/mirrorlist
echo -e "${green}Mirrors Updated${nc}"
notify-send "Mirror Update" "Mirror update completed successfully!"
