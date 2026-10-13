#!/usr/bin/env bash
# https://github.com/PiercingXX
#
# Surface Linux kernel for Arch (standalone).
# linux-mod's drivers_surface (Drivers & Hardware menu) is the canonical,
# multi-distro version; this mirrors its Arch path for running by hand.

set -euo pipefail

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../resources/.scripts/lib/common.sh"

KEY_URL="https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc"
KEY_ID="56C464BAAC421453"

refuse_root
detect_distro
is_arch_like || die "surface-kernel.sh is Arch-only. Use linux-mod's Drivers & Hardware menu on ${DISTRO_ID:-this distro}."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --- Signing key: download, verify the fingerprint, then trust it ---------
say "Fetching linux-surface signing key..."
curl -fsSL "$KEY_URL" -o "$tmp/surface.asc"
fpr=$(gpg --with-colons --import-options show-only --import "$tmp/surface.asc" 2>/dev/null \
    | awk -F: '/^fpr:/ {print $10; exit}')
if [[ "${fpr^^}" != *"$KEY_ID" ]]; then
    die "Key fingerprint mismatch (got '${fpr:-none}', expected *$KEY_ID). Aborting."
fi
ok "Key fingerprint OK: $fpr"
sudo pacman-key --add "$tmp/surface.asc"
sudo pacman-key --lsign-key "$KEY_ID"

# --- Repo -----------------------------------------------------------------
if ! grep -q '^\[linux-surface\]' /etc/pacman.conf; then
    printf '\n[linux-surface]\nServer = https://pkg.surfacelinux.com/arch/\n' \
        | sudo tee -a /etc/pacman.conf >/dev/null
    ok "Added [linux-surface] to /etc/pacman.conf"
fi

# --- Packages -------------------------------------------------------------
sudo pacman -Syu --noconfirm
pkg_install linux-surface linux-surface-headers iptsd
# Arch split linux-firmware in 2025; Surface WiFi/BT needs the marvell + intel parts
pkg_install linux-firmware-marvell linux-firmware-intel
if [ -d /sys/firmware/efi ] && command_exists mokutil && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
    pkg_install linux-surface-secureboot-mok
fi
helper=$(aur_helper)
if [ -n "$helper" ]; then
    "$helper" -S --needed --noconfirm libwacom-surface || warn "libwacom-surface (AUR) failed."
else
    warn "No AUR helper (paru/yay); skipping libwacom-surface."
fi

# surface-dtx-daemon only matters on detachable Surface Book models
if grep -qi 'Surface Book' /sys/class/dmi/id/product_name 2>/dev/null; then
    pkg_install surface-dtx-daemon
    sudo systemctl enable --now surface-dtx-daemon.service
    systemctl --user enable --now surface-dtx-userd.service || true
fi

# --- Bootloader -----------------------------------------------------------
# Reuse the running kernel's options (keeps root=, rootflags=subvol=, etc.)
current_options() {
    tr ' ' '\n' < /proc/cmdline | grep -vE '^(BOOT_IMAGE|initrd)=' | tr '\n' ' ' | sed 's/ *$//'
}

if command_exists grub-mkconfig && [ -f /etc/default/grub ]; then
    sudo grub-mkconfig -o /boot/grub/grub.cfg
elif command_exists bootctl && sudo bootctl is-installed >/dev/null 2>&1; then
    esp=$(bootctl --print-esp-path 2>/dev/null || echo /boot)
    entry="$esp/loader/entries/linux-surface.conf"
    if ! sudo grep -qs 'linux-surface' "$esp"/loader/entries/*.conf; then
        opts=$(current_options)
        if [ -z "$opts" ]; then
            opts="root=PARTUUID=$(findmnt -no PARTUUID /) rw"
        fi
        ucode=""
        [ -f "$esp/intel-ucode.img" ] && ucode="initrd  /intel-ucode.img"
        sudo tee "$entry" >/dev/null <<EOF
title   Arch Linux (Surface)
linux   /vmlinuz-linux-surface
${ucode}
initrd  /initramfs-linux-surface.img
options ${opts}
EOF
        sudo sed -i '/^$/d' "$entry"
        if grep -q '^default' "$esp/loader/loader.conf" 2>/dev/null; then
            sudo sed -i 's/^default.*/default linux-surface.conf/' "$esp/loader/loader.conf"
        else
            echo "default linux-surface.conf" | sudo tee -a "$esp/loader/loader.conf" >/dev/null
        fi
        ok "Wrote $entry"
    fi
else
    warn "Unknown bootloader: select the linux-surface kernel in your boot manager manually."
fi

ok "Surface kernel installed. Reboot to use it."
