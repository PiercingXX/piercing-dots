#!/bin/bash
# GitHub.com/PiercingXX

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

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

# Resolve target user from directory ownership; avoid SUDO_USER
builddir=$(pwd)
dir_owner="$(stat -c '%U' "$builddir")"
if getent passwd "$dir_owner" >/dev/null 2>&1; then
    username="$dir_owner"
else
    username="$(getent passwd 1000 | cut -d: -f1)"
    [ -z "$username" ] && username="$(id -un)"
fi
home_dir="$(getent passwd "$username" | cut -d: -f6)"
[ -z "$home_dir" ] && home_dir="$HOME"

can_apply_gnome_customizations() {
    command -v gsettings >/dev/null 2>&1 || return 1
    command -v dconf >/dev/null 2>&1 || return 1
    [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || return 1
    [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || return 1
    return 0
}

set_kv_quoted() {
    # set_kv_quoted /path/to/file KEY VALUE
    local file="$1" key="$2" value="$3"
    if [ -f "$file" ] && grep -qE "^${key}=" "$file"; then
        sudo sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$file"
    else
        echo "${key}=\"${value}\"" | sudo tee -a "$file" >/dev/null
    fi
}

set_kv_unquoted() {
    # set_kv_unquoted /path/to/file KEY VALUE
    local file="$1" key="$2" value="$3"
    if [ -f "$file" ] && grep -qE "^${key}=" "$file"; then
        sudo sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        echo "${key}=${value}" | sudo tee -a "$file" >/dev/null
    fi
}

set_keyboard_layout() {
    # Usage: set_keyboard_layout <tty_keymap> <x11_layout> <x11_variant>
    local tty_keymap="${1:-colemak}"
    local x11_layout="${2:-us}"
    local x11_variant="${3:-colemak}"

    local persistent_set=0

    echo "Applying keyboard layout: TTY=${tty_keymap}, X11=${x11_layout}/${x11_variant}"

    # Runtime TTY (immediate effect)
    if command -v loadkeys >/dev/null 2>&1; then
        if sudo loadkeys "$tty_keymap"; then
            echo "Applied runtime TTY keymap via loadkeys."
        else
            echo "Warning: loadkeys could not apply '${tty_keymap}' right now."
        fi
    fi

    # systemd path (Fedora, Arch, Debian, Ubuntu, etc. when localectl exists)
    if command -v localectl >/dev/null 2>&1; then
        if localectl list-keymaps 2>/dev/null | grep -qx "$tty_keymap"; then
            if sudo localectl set-keymap "$tty_keymap"; then
                persistent_set=1
                echo "Persistent TTY keymap set via localectl."
            fi
        else
            echo "Warning: keymap '${tty_keymap}' not found in localectl list-keymaps."
        fi

        # X11 layout persistence via localectl when available
        if sudo localectl set-x11-keymap "$x11_layout" "" "$x11_variant" 2>/dev/null; then
            echo "Persistent X11 keymap set via localectl."
        fi
    fi

    # Debian/Ubuntu fallback (non-interactive)
    if [ -f /etc/default/keyboard ]; then
        set_kv_quoted /etc/default/keyboard XKBLAYOUT "$x11_layout"
        set_kv_quoted /etc/default/keyboard XKBVARIANT "$x11_variant"
        set_kv_quoted /etc/default/keyboard XKBMODEL "pc105"
        set_kv_quoted /etc/default/keyboard XKBOPTIONS ""
        persistent_set=1
        echo "Updated /etc/default/keyboard."
        if command -v setupcon >/dev/null 2>&1; then
            sudo setupcon || true
        fi
    fi

    # Generic vconsole fallback (non-systemd/minimal systems)
    if [ -f /etc/vconsole.conf ] || [ ! -e /etc/vconsole.conf ]; then
        set_kv_unquoted /etc/vconsole.conf KEYMAP "$tty_keymap"
        persistent_set=1
        echo "Updated /etc/vconsole.conf."
    fi

    # OpenRC/Gentoo/Alpine style fallback
    if [ -f /etc/conf.d/keymaps ]; then
        set_kv_quoted /etc/conf.d/keymaps keymap "$tty_keymap"
        persistent_set=1
        echo "Updated /etc/conf.d/keymaps."
    fi

    if [ "$persistent_set" -eq 1 ]; then
        echo "Keyboard layout persistence configured successfully."
    else
        echo "Warning: no known persistent keyboard config path found on this distro."
        return 1
    fi
}

#Create necessary directories and copy configuration files
    # Replace .bashrc
        cp -f resources/bash/.bashrc "$home_dir"/.bashrc
        chown "$username":"$username" "$home_dir"/.bashrc
        echo "Replaced .bashrc."
    # Copy .tmux.conf
        cp -f resources/tmux/.tmux.conf "$home_dir"/.tmux.conf
        chown "$username":"$username" "$home_dir"/.tmux.conf
        echo "Copied .tmux.conf."
        # Clone TPM if it doesn't exist
            if [ ! -d "$home_dir/.tmux/plugins/tpm" ]; then
                sudo install -d -o "$username" -g "$username" "$home_dir/.tmux/plugins"
                sudo -H -u "$username" git clone https://github.com/tmux-plugins/tpm "$home_dir/.tmux/plugins/tpm"
            fi
        # Install plugins as the user
            sudo -u "$username" bash -c "$home_dir/.tmux/plugins/tpm/bin/install_plugins"
        echo "Installed Tmux plugins."
    # Update scripts
        rm -Rf "$home_dir"/.scripts/*
        sudo install -d -o "$username" -g "$username" "$home_dir"/.scripts
        cp -rf resources/.scripts/* "$home_dir"/.scripts/
        sudo chown -R "$username":"$username" "$home_dir"/.scripts
        chmod -R +x "$home_dir"/.scripts/*
        echo "Updated .scripts directory."
    # Ensure parent directories have correct ownership
        sudo install -d -o "$username" -g "$username" "$home_dir/.local" "$home_dir/.local/share" "$home_dir/.local/bin" "$home_dir/.config"
    # .font directory
        if [ ! -d "$home_dir/.fonts" ]; then
            sudo install -d -o "$username" -g "$username" "$home_dir/.fonts"
        fi
    # .icons directory
        if [ ! -d "$home_dir/.icons" ]; then
            sudo install -d -o "$username" -g "$username" "$home_dir/.icons"
        fi
    # Background and Profile Image Directories
        if [ ! -d "$home_dir/Pictures/backgrounds" ]; then
            sudo install -d -o "$username" -g "$username" "$home_dir/Pictures" "$home_dir/Pictures/backgrounds"
        fi
        if [ ! -d "$home_dir/Pictures/profile-image" ]; then
            sudo install -d -o "$username" -g "$username" "$home_dir/Pictures" "$home_dir/Pictures/profile-image"
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
    # Copy Piercing Dots config into user's .config
        sudo install -d -o "$username" -g "$username" "$home_dir/.config"
        sudo rm -rf "$home_dir/.config/fastfetch"
        sudo install -d -o "$username" -g "$username" "$home_dir/.config/fastfetch"
        for dot_path in dots/*; do
            if [ "$(basename "$dot_path")" = "fastfetch" ]; then
                continue
            fi
            cp -Rf "$dot_path" "$home_dir"/.config/
        done
        install -Dm644 dots/fastfetch/config.jsonc "$home_dir/.config/fastfetch/config.jsonc"
        sudo chown -R "$username":"$username" "$home_dir"/.config
        cd "$builddir" || exit
        echo "Copied Piercing Dots Config Files."
        if [ -n "${XDG_RUNTIME_DIR:-}" ] && systemctl --user show-environment >/dev/null 2>&1; then
            systemctl --user daemon-reload
            systemctl --user restart xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service >/dev/null 2>&1 || true
            systemctl --user restart xdg-desktop-portal.service >/dev/null 2>&1 || \
                systemctl --user start xdg-desktop-portal.service >/dev/null 2>&1 || true
            echo "Reloaded user systemd units and refreshed xdg-desktop-portal."
        fi
    # Copy FZF to /usr
        sudo cp -rf resources/fzf /usr/share/fzf
        sudo chmod -R +x /usr/share/fzf/
        echo "Copied FZF to /usr/share/fzf" 
    # Deploy greetd config
        sudo install -d -m 755 /etc/greetd
        if [ -f /etc/greetd/config.toml ]; then
            sudo cp -f /etc/greetd/config.toml /etc/greetd/config.toml.bak
        fi
        sudo install -m 644 resources/greetd/config.toml /etc/greetd/config.toml
        echo "Deployed greetd config to /etc/greetd/config.toml."
    # Set keyboard layout (distro-agnostic)
        set_keyboard_layout "colemak" "us" "colemak"
    # Copy Backgrounds
        cp -Rf resources/backgrounds/* "$home_dir"/Pictures/backgrounds
        sudo chown -R "$username":"$username" "$home_dir"/Pictures/backgrounds
        cp -Rf resources/profile-image/* "$home_dir"/Pictures/profile-image
        sudo chown -R "$username":"$username" "$home_dir"/Pictures/profile-image
        cd "$builddir" || exit
        echo "Copied Backgrounds and Profile Images."
    # Copy Refs to Download folder
        mkdir -p "$home_dir"/Downloads
        cp -Rf resources/refs/* "$home_dir"/Downloads
        echo "Copied reference files to Downloads."
    # Install Black Minimalistic cursor theme for Linux desktops
        cd scripts || exit
        chmod u+x install-black-minimalistic-cursor.sh
        ./install-black-minimalistic-cursor.sh
        cd "$builddir" || exit
        echo "Installed Black Minimalistic cursor theme."
    # Apply Piercing Gnome Customizations
        if can_apply_gnome_customizations; then
            cd scripts || exit
            chmod u+x gnome-customizations.sh
            ./gnome-customizations.sh
            wait
            cd "$builddir" || exit
            echo "Applied Piercing Gnome Customizations."
        else
            echo "Skipping GNOME customizations during install; no active GNOME session bus/display."
            echo "Run scripts/gnome-customizations.sh after logging into GNOME."
        fi
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
    # Setup Terminal Session for GDM
        #echo "Setting up Terminal Session..."
        #cd scripts || exit
        #chmod u+x setup-terminal-session.sh
        #./setup-terminal-session.sh
        #cd "$builddir" || exit
        #echo "Terminal Session setup complete."
    # Set PRETTY_NAME in /etc/os-release
        pretty_name
    # Ollama install
#        echo -e "${YELLOW}Installing Ollama...${NC}"         cd scripts || exit
#            cd scripts || exit
#            chmod u+x ollama-setup.sh
#            sudo ./ollama-setup.sh
#           wait
#            cd "$builddir" || exit
#        echo -e "${GREEN}Ollama Installed & Modified successfully!${NC}"
    # SFP+ Fiberoptic Card Lockout Fix
        echo -e "${YELLOW}Applying SFP Fiber Lockout Fix...${NC}"
        cd scripts || exit
            chmod u+x sfp-fiber-lockout-fix.sh
            sudo ./sfp-fiber-lockout-fix.sh --apply
            wait
            cd "$builddir" || exit
        echo -e "${GREEN}SFP Fiber Lockout Fix applied successfully!${NC}"
    # Strip Cursor/Claude/Grok Co-authored-by trailers on commit (Skippy stays)
        echo -e "${YELLOW}Installing git vendor-trailer hook...${NC}"
        cd scripts || exit
            chmod u+x install-git-vendor-trailer-hook.sh
            sudo -H -u "$username" ./install-git-vendor-trailer-hook.sh
            cd "$builddir" || exit
        echo -e "${GREEN}Git vendor-trailer hook installed.${NC}"
