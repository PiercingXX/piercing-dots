#!/bin/bash
# GitHub.com/PiercingXX

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
            fi
            chown -R "$username":"$username" "$HOME"/.fonts
        # .icons directory
            if [ ! -d "$HOME/.icons" ]; then
                mkdir -p /home/"$username"/.icons
            fi
            chown -R "$username":"$username" /home/"$username"/.icons
        # Background and Profile Image Directories
            if [ ! -d "$HOME/$username/Pictures/backgrounds" ]; then
                mkdir -p /home/"$username"/Pictures/backgrounds
            fi
            chown -R "$username":"$username" /home/"$username"/Pictures/backgrounds
            if [ ! -d "$HOME/$username/Pictures/profile-image" ]; then
                mkdir -p /home/"$username"/Pictures/profile-image
            fi
            chown -R "$username":"$username" /home/"$username"/Pictures/profile-image
        # fstab external drive mounting directory
            if [ ! -d "$HOME/.media/Working-Storage" ]; then
                mkdir -p /home/"$username"/media/Working-Storage
            fi
            chown "$username":"$username" /home/"$username"/media/Working-Storage
            if [ ! -d "$HOME/.media/Archived-Storage" ]; then
                mkdir -p /home/"$username"/media/Archived-Storage
            fi
            chown "$username":"$username" /home/"$username"/media/Archived-Storage
    # Clone Piercing Dots Repo
        cp -Rf dots/* /home/"$username"/.config/
        chown "$username":"$username" -R /home/"$username"/.config/*
        cd "$builddir" || exit
    # Copy Backgrounds
        cp -Rf backgrounds/* /home/"$username"/Pictures/backgrounds
        chown -R "$username":"$username" /home/"$username"/Pictures/backgrounds
        cp -Rf profile-image/* /home/"$username"/Pictures/profile-image
        chown -R "$username":"$username" /home/"$username"/Pictures/profile-images
        cd "$builddir" || exit
    # Copy Refs to Download folder
        cp -Rf refs/* /home/"$username"/Downloads
    # Apply Beautiful Bash
        echo -e "${YELLOW}Installing Beautiful Bash...${NC}"
        git clone https://github.com/christitustech/mybash
            chmod -R u+x mybash
            chown -R "$username":"$username" mybash
            cd mybash || exit
            ./setup.sh
            wait
            cd "$builddir" || exit
            rm -rf mybash
    # Replace .bashrc
        cp -Rf bash/.bashrc /home/"$username"/
        chmod u+x /home/"$username"/.bashrc
        chown -R "$username":"$username" /home/"$username"/.bashrc
    # Clean Up
        rm -Rf piercing-dots
    echo -e "${GREEN}PiercingXX Rice Applied Successfully!${NC}"