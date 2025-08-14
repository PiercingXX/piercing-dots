#!/bin/bash
# GitHub.com/PiercingXX

username=$(id -u -n 1000)
builddir=$(pwd)

# Copy PiercingXX GIMP dots into dots folder for Stable and Beta

# Purge existing GIMP config files
    rm -Rf /home/"$username"/.var/app/org.gimp.GIMP/config/GIMP/*
    rm -Rf /home/"$username"/.config/GIMP/*
# Copy GIMP dots
    mkdir -p /home/"$username"/.config/GIMP/3.0
    chown -R "$username":"$username" /home/"$username"/.config/GIMP
    cp -Rf ../dots/GIMP/* /home/"$username"/.config/GIMP/
    chown "$username":"$username" -R /home/"$username"/.config/GIMP
    cd "$builddir" || exit