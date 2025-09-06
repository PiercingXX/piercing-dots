#!/bin/bash
# https://github.com/PiercingXX

# Surface Linux Kernel Installation Script

# For Microsoft Surface Devices
    curl -s https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc \
        | sudo pacman-key --add -
    sudo pacman-key --finger 56C464BAAC421453
    sudo pacman-key --lsign-key 56C464BAAC421453
        if [ -f "/etc/pacman.conf" ]; then
            cat /etc/pacman.conf >> /etc/pacman.conf
            echo "Server = https://pkg.surfacelinux.com/arch/" >> /etc/pacman.conf
        else
            echo "The file does not exist."
        fi
    paru -Syu --noconfirm
    paru -Sy libwacom-surface --noconfirm
    sudo pacman -Syu --noconfirm
    sudo pacman -S linux-surface linux-surface-headers iptsd --noconfirm
    sudo pacman -S linux-firmware-marvell --noconfirm
    sudo pacman -S linux-surface-secureboot-mok --noconfirm
    paru -S surface-dtx-daemon --noconfirm
    systemctl enable surface-dtx-daemon.service
    systemctl --user surface-dtx-userd.service
    sudo touch /boot/loader/entries/surface.conf
        cat /boot/loader/entries/surface.conf >> /boot/loader/entries/surface.conf
        echo "
        title Arch Surface
        linux /vmlinuz-linux-surface
        initrd  /initramfs-linux-surface.img
        options root=LABEL=arch rw"
