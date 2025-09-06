#!/bin/bash
# GitHub.com/PiercingXX

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

# Check for active network connection
    if command_exists nmcli; then
        state=$(nmcli -t -f STATE g)
        if [[ "$state" != connected ]]; then
            echo "Network connectivity is required to continue."
            exit 1
        fi
    else
        # Fallback: ensure at least one interface has an IPv4 address
        if ! ip -4 addr show | grep -q "inet "; then
            echo "Network connectivity is required to continue."
            exit 1
        fi
    fi
        # Additional ping test to confirm internet reachability
        if ! ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
            echo "Network connectivity is required to continue."
            exit 1
        fi

username=$(id -u -n 1000)
builddir=$(pwd)

# PiercingXX Rice
    # Update Maintenance Script (run 'xx' in terminal)
        rm -f /home/"$username"/maintenance.sh
        cp -f scripts/maintenance.sh /home/"$username"/
        chown "$username":"$username" /home/"$username"/maintenance.sh
        chmod +x /home/"$username"/maintenance.sh
    # Make Directories if needed
        # .font directory
            if [ ! -d "$HOME/.fonts" ]; then
                mkdir -p "$HOME/.fonts"
                chown -R "$username":"$username" "$HOME"/.fonts
            fi
        # .icons directory
            if [ ! -d "$HOME/.icons" ]; then
                mkdir -p /home/"$username"/.icons
                chown -R "$username":"$username" /home/"$username"/.icons
            fi
        # Background and Profile Image Directories
            if [ ! -d "$HOME/$username/Pictures/backgrounds" ]; then
                mkdir -p /home/"$username"/Pictures/backgrounds
                chown -R "$username":"$username" /home/"$username"/Pictures/backgrounds
            fi
            if [ ! -d "$HOME/$username/Pictures/profile-image" ]; then
                mkdir -p /home/"$username"/Pictures/profile-image
                chown -R "$username":"$username" /home/"$username"/Pictures/profile-image
            fi
        # fstab external drive mounting directory
            if [ ! -d "/media/Working-Storage" ]; then
                sudo mkdir -p /media/Working-Storage
                sudo chown "$username":"$username" /media/Working-Storage
            fi
            if [ ! -d "/media/Archived-Storage" ]; then
                sudo mkdir -p /media/Archived-Storage
                sudo chown "$username":"$username" /media/Archived-Storage
            fi
    # Clone Piercing Dots Repo
        cp -Rf dots/* /home/"$username"/.config/
        chown "$username":"$username" -R /home/"$username"/.config/*
        cd "$builddir" || exit
    # Copy Backgrounds
        cp -Rf resources/backgrounds/* /home/"$username"/Pictures/backgrounds
        chown -R "$username":"$username" /home/"$username"/Pictures/backgrounds
        cp -Rf resources/profile-image/* /home/"$username"/Pictures/profile-image
        chown -R "$username":"$username" /home/"$username"/Pictures/profile-images
        cd "$builddir" || exit
    # Copy Refs to Download folder
        cp -Rf resources/refs/* /home/"$username"/Downloads
    # Apply Piercing Gnome Customizations
        cd scripts || exit
        chmod u+x gnome-customizations.sh
        ./gnome-customizations.sh
        wait
        cd "$builddir" || exit
    # Replace .bashrc
        cp -f resources/bash/.bashrc /home/"$username"/.bashrc
        source /home/"$username"/.bashrc
    # Set PRETTY_NAME in /etc/os-release
        pretty_name