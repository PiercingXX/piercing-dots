#!/bin/bash
# GitHub.com/PiercingXX

# Detect distribution and version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_NAME="${ID^}"      # Capitalize first letter
    DISTRO_VERSION="${VERSION_ID:-}"
else
    echo "Cannot detect distribution!"
    exit 1
fi

# Compose new PRETTY_NAME
NEW_PRETTY_NAME="PiercingXX $DISTRO_NAME $DISTRO_VERSION"

# Backup original file
sudo cp /etc/os-release /etc/os-release.bak

# Replace PRETTY_NAME in /etc/os-release
sudo sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"$NEW_PRETTY_NAME\"/" /etc/os-release

echo "PRETTY_NAME set to \"$NEW_PRETTY_NAME\" in /etc/os-release"