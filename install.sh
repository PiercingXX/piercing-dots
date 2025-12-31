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

## Check for active network connection
#    if command_exists nmcli; then
#        state=$(nmcli -t -f STATE g)
#        if [[ "$state" != connected ]]; then
#            echo "Network connectivity is required to continue."
#            exit 1
#        fi
#    else
#        # Fallback: ensure at least one interface has an IPv4 address
#        if ! ip -4 addr show | grep -q "inet "; then
#            echo "Network connectivity is required to continue."
#            exit 1
#        fi
#    fi
#        # Additional ping test to confirm internet reachability
#        if ! ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
#            echo "Network connectivity is required to continue."
#            exit 1
#        fi

username=$(id -u -n 1000)
builddir=$(pwd)


#Create necessary directories and copy configuration files
    # Replace .bashrc
        cp -f resources/bash/.bashrc /home/"$username"/.bashrc
        source /home/"$username"/.bashrc
        echo "Replaced .bashrc."
    # Copy .tmux.conf
        cp -f resources/tmux/.tmux.conf /home/"$username"/.tmux.conf
        chown "$username":"$username" /home/"$username"/.tmux.conf
        echo "Copied .tmux.conf."
    # Update scripts
        rm -Rf /home/"$username"/.scripts/*
        sudo mkdir -p /home/"$username"/.scripts
        sudo chown "$username":"$username" /home/"$username"/.scripts
        cp -rf resources/.scripts/* /home/"$username"/.scripts/
        sudo chown -R "$username":"$username" /home/"$username"/.scripts
        chmod -R +x /home/"$username"/.scripts/*
        echo "Updated .scripts directory."
    # .font directory
        if [ ! -d "$HOME/.fonts" ]; then
            sudo mkdir -p "$HOME/.fonts"
            sudo chown -R "$username":"$username" "$HOME"/.fonts
        fi
    # .icons directory
        if [ ! -d "$HOME/.icons" ]; then
            sudo mkdir -p /home/"$username"/.icons
            sudo chown -R "$username":"$username" /home/"$username"/.icons
        fi
    # Background and Profile Image Directories
        if [ ! -d "$HOME/$username/Pictures/backgrounds" ]; then
            sudo mkdir -p /home/"$username"/Pictures/backgrounds
            sudo chown -R "$username":"$username" /home/"$username"/Pictures/backgrounds
        fi
        if [ ! -d "$HOME/$username/Pictures/profile-image" ]; then
            sudo mkdir -p /home/"$username"/Pictures/profile-image
            sudo chown -R "$username":"$username" /home/"$username"/Pictures/profile-image
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
        echo "Created necessary directories."
    # Clone Piercing Dots Repo
        cp -Rf dots/* /home/"$username"/.config/
        chown "$username":"$username" -R /home/"$username"/.config/*
        cd "$builddir" || exit
        echo "Copied Piercing Dots Config Files."
    # Copy FZF to /usr
        sudo cp -rf resources/fzf /usr/share/fzf
        sudo chmod -R +x /usr/share/fzf/
        echo "Copied FZF to /usr/share/fzf" 
    # Copy Backgrounds
        cp -Rf resources/backgrounds/* /home/"$username"/Pictures/backgrounds
        chown -R "$username":"$username" /home/"$username"/Pictures/backgrounds
        cp -Rf resources/profile-image/* /home/"$username"/Pictures/profile-image
        chown -R "$username":"$username" /home/"$username"/Pictures/profile-image
        cd "$builddir" || exit
        echo "Copied Backgrounds and Profile Images."
    # Copy Refs to Download folder
        cp -Rf resources/refs/* /home/"$username"/Downloads
        echo "Copied reference files to Downloads."
    # Apply Piercing Gnome Customizations
        cd scripts || exit
        chmod u+x gnome-customizations.sh
        ./gnome-customizations.sh
        wait
        cd "$builddir" || exit
        echo "Applied Piercing Gnome Customizations."
    # Set Boot Beep (skip when no bootloader detected)
        if { [ -d /sys/firmware/efi/efivars ] && [ -d /boot/loader ]; } || grep -qi grub /proc/cmdline || [ -f /etc/default/grub ]; then
            echo -e "${YELLOW}Setting Boot Beep...${NC}"
                cd scripts || exit
                chmod u+x set_boot_beep.sh
                ./set_boot_beep.sh
                cd "$builddir" || exit
            echo -e "${GREEN}Boot Beep Set successfully!${NC}"
        else
            echo -e "${YELLOW}Bootloader not detected; skipping Boot Beep.${NC}"
        fi
    # Set PRETTY_NAME in /etc/os-release
        pretty_name