#!/usr/bin/env bash
# GitHub.com/PiercingXX
#
# Zero the bootloader menu timeout and beep once the system has booted.
# Supports systemd-boot and GRUB; the beep runs from systemd, runit
# (rc.local) or OpenRC (local.d), whichever init is active.

set -euo pipefail

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../resources/.scripts/lib/common.sh"

detect_distro

# The command that actually makes a sound: `beep` if installed, otherwise a
# BEL on the console, which the PC speaker plays once pcspkr is loaded.
beep_cmd() {
    if command_exists beep; then
        command -v beep
    else
        echo "/bin/sh -c 'printf \"\\\\a\" > /dev/console'"
    fi
}

ensure_pcspkr() {
    # Some distros blacklist pcspkr; load it at boot so the BEL is audible
    if [ -d /etc/modules-load.d ]; then
        echo pcspkr | sudo tee /etc/modules-load.d/pcspkr.conf >/dev/null
    elif [ -f /etc/modules ] && ! grep -qx pcspkr /etc/modules; then
        echo pcspkr | sudo tee -a /etc/modules >/dev/null
    fi
    if grep -rqs '^blacklist pcspkr' /etc/modprobe.d/; then
        warn "pcspkr is blacklisted in /etc/modprobe.d; the boot beep will be silent until that line is removed."
    fi
}

enable_beep_systemd() {
    sudo tee /etc/systemd/system/startup-beep.service >/dev/null <<EOF
[Unit]
Description=Beep at startup
After=multi-user.target

[Service]
Type=oneshot
ExecStartPre=-/usr/bin/modprobe pcspkr
ExecStart=$(beep_cmd)

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable startup-beep.service
}

# runit (Void, Artix-runit) runs /etc/rc.local at the end of stage 2
enable_beep_rc_local() {
    local line='printf "\a" > /dev/console'
    if [ -f /etc/rc.local ]; then
        grep -qF "$line" /etc/rc.local && return 0
        if grep -q '^exit 0' /etc/rc.local; then
            sudo sed -i "/^exit 0/i $line" /etc/rc.local
        else
            echo "$line" | sudo tee -a /etc/rc.local >/dev/null
        fi
    else
        printf '#!/bin/sh\n%s\nexit 0\n' "$line" | sudo tee /etc/rc.local >/dev/null
        sudo chmod +x /etc/rc.local
    fi
}

# OpenRC (Alpine, postmarketOS, Artix-openrc) runs /etc/local.d/*.start
enable_beep_openrc() {
    sudo install -d /etc/local.d
    printf '#!/bin/sh\nprintf "\\a" > /dev/console\n' | sudo tee /etc/local.d/beep.start >/dev/null
    sudo chmod +x /etc/local.d/beep.start
    sudo rc-update add local default >/dev/null 2>&1 || true
}

enable_beep() {
    ensure_pcspkr
    case "$INIT" in
        systemd) enable_beep_systemd ;;
        runit)   enable_beep_rc_local ;;
        openrc)  enable_beep_openrc ;;
        *)       warn "No boot-beep hook for init '$INIT'; skipping the beep." ;;
    esac
}

set_systemd_boot_timeout() {
    local esp conf
    esp=$(bootctl --print-esp-path 2>/dev/null || echo /boot)
    conf="$esp/loader/loader.conf"
    if sudo grep -q '^timeout' "$conf" 2>/dev/null; then
        sudo sed -i 's/^timeout.*/timeout 0/' "$conf"
    else
        echo "timeout 0" | sudo tee -a "$conf" >/dev/null
    fi
}

set_grub_timeout() {
    if grep -q '^GRUB_TIMEOUT=' /etc/default/grub; then
        sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
    else
        echo 'GRUB_TIMEOUT=0' | sudo tee -a /etc/default/grub >/dev/null
    fi
    if command_exists update-grub; then
        sudo update-grub
    elif command_exists grub-mkconfig && [ -d /boot/grub ]; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    elif command_exists grub2-mkconfig && [ -d /boot/grub2 ]; then
        sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    else
        warn "No GRUB update command found. Regenerate grub.cfg manually."
    fi
}

if command_exists bootctl && sudo bootctl is-installed >/dev/null 2>&1; then
    say "Detected systemd-boot."
    set_systemd_boot_timeout
elif [ -f /etc/default/grub ]; then
    say "Detected GRUB."
    set_grub_timeout
else
    say "Bootloader not detected. Skipping boot beep configuration."
    exit 0
fi

enable_beep
ok "Done."
