#!/bin/bash
# GitHub.com/PiercingXX
#
# Deploys the piercing-dots rice into the current user's home.
# Normally run by linux-mod (as the normal user, from the repo dir); also
# works standalone:  ./install.sh   or   sudo ./install.sh  (uses $SUDO_USER)
#
# Environment knobs (all optional):
#   PIERCINGXX_KEYMAP=colemak        TTY keymap ("skip" leaves keyboard alone)
#   PIERCINGXX_XKB_LAYOUT=us         X11/Wayland default layout
#   PIERCINGXX_XKB_VARIANT=colemak   X11/Wayland default variant
#   PIERCINGXX_BOOT_BEEP=1|0         startup beep (default 1)
#   PIERCINGXX_POWER_SUDOERS=0       skip the NOPASSWD shutdown/reboot drop-in
#                                    (PIERCINGXX_NO_POWER_SUDOERS=1 also works)
#   PIERCINGXX_SET_PRETTY_NAME=0     keep the distro's PRETTY_NAME
#   PIERCINGXX_SKIP_GNOME=1          skip gnome-customizations.sh (linux-mod runs it itself)
#   PIERCINGXX_CREATE_MEDIA_DIRS=1   create /media/Working-Storage + Archived-Storage
#   PIERCINGXX_SFP_FIX=1|0           force/skip the ixgbe SFP fix (default: only if an ixgbe NIC exists)

# Always work from the repo dir, wherever we were called from
builddir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
cd "$builddir" || exit 1

# shellcheck source=resources/.scripts/lib/common.sh
. "$builddir/resources/.scripts/lib/common.sh"
detect_distro

# ---------------------------------------------------------------------------
# Target user: the caller, or $SUDO_USER when run with sudo. Never root.
# ---------------------------------------------------------------------------
if [ "$EUID" -eq 0 ]; then
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
        username="$SUDO_USER"
    else
        die "Run install.sh as your normal user (or via sudo from that user). Refusing to install the rice into /root."
    fi
else
    username="$(id -un)"
fi
home_dir="$(getent passwd "$username" | cut -d: -f6)"
[ -n "$home_dir" ] && [ -d "$home_dir" ] || die "Could not resolve the home directory for $username."
user_group="$(id -gn "$username")"

# Run a command as the target user (no-op wrapper when we already are that user)
run_as_user() {
    if [ "$EUID" -eq 0 ]; then
        sudo -H -u "$username" "$@"
    else
        "$@"
    fi
}

pretty_name() {
    # /etc/os-release is the admin override for /usr/lib/os-release (os-release(5)).
    # Rebuild it from the vendor file every run so new upstream fields are kept,
    # change only PRETTY_NAME, and keep a one-time backup of the original.
    local vendor=/usr/lib/os-release
    [ -f "$vendor" ] || vendor=/etc/os-release
    [ -f "$vendor" ] || { warn "Cannot detect distribution; skipping PRETTY_NAME."; return 1; }

    local id version new_name tmp
    id=$(. "$vendor" && printf '%s' "${ID:-linux}")
    version=$(. "$vendor" && printf '%s' "${VERSION_ID:-}")
    new_name="PiercingXX ${id^}${version:+ $version}"

    if [ ! -e /etc/os-release.piercingxx.orig ] && [ ! -L /etc/os-release.piercingxx.orig ]; then
        sudo cp -P /etc/os-release /etc/os-release.piercingxx.orig 2>/dev/null || true
    fi
    tmp="$(mktemp)"
    sed "s/^PRETTY_NAME=.*/PRETTY_NAME=\"$new_name\"/" "$vendor" > "$tmp"
    grep -q '^PRETTY_NAME=' "$tmp" || echo "PRETTY_NAME=\"$new_name\"" >> "$tmp"
    # rm first: if /etc/os-release is a symlink, install would write through it
    # into the package-owned vendor file.
    sudo rm -f /etc/os-release
    sudo install -m 644 "$tmp" /etc/os-release
    rm -f "$tmp"
    echo "PRETTY_NAME set to \"$new_name\" in /etc/os-release"
}

can_apply_gnome_customizations() {
    command_exists gsettings || return 1
    command_exists dconf || return 1
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

current_tty_keymap() {
    if command_exists localectl; then
        localectl status 2>/dev/null | awk -F': ' '/VC Keymap/ {gsub(/ /,"",$2); print $2; exit}'
    elif [ -f /etc/vconsole.conf ]; then
        sed -n 's/^KEYMAP=//p' /etc/vconsole.conf | tr -d '"'
    fi
}

current_x11_variant() {
    if command_exists localectl; then
        localectl status 2>/dev/null | awk -F': ' '/X11 Variant/ {gsub(/ /,"",$2); print $2; exit}'
    elif [ -f /etc/default/keyboard ]; then
        sed -n 's/^XKBVARIANT=//p' /etc/default/keyboard | tr -d '"'
    fi
}

set_keyboard_layout() {
    # Usage: set_keyboard_layout <tty_keymap> <x11_layout> <x11_variant>
    local tty_keymap="${1:-colemak}"
    local x11_layout="${2:-us}"
    local x11_variant="${3:-colemak}"

    if [ "$tty_keymap" = skip ]; then
        echo "PIERCINGXX_KEYMAP=skip: leaving the keyboard layout alone."
        return 0
    fi
    if [ "$(current_tty_keymap)" = "$tty_keymap" ] && [ "$(current_x11_variant)" = "$x11_variant" ]; then
        echo "Keyboard already set to ${tty_keymap} / ${x11_layout} ${x11_variant}; skipping."
        return 0
    fi

    local persistent_set=0

    echo "Applying keyboard layout: TTY=${tty_keymap}, X11=${x11_layout}/${x11_variant}"

    # Runtime TTY (immediate effect)
    if command_exists loadkeys; then
        if sudo loadkeys "$tty_keymap" 2>/dev/null; then
            echo "Applied runtime TTY keymap via loadkeys."
        else
            echo "Warning: loadkeys could not apply '${tty_keymap}' right now."
        fi
    fi

    # systemd path (Arch, Fedora, Debian, openSUSE, ...)
    if command_exists localectl && [ "$INIT" = systemd ]; then
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

    # Debian/Ubuntu/phones (non-interactive)
    if [ -f /etc/default/keyboard ]; then
        set_kv_quoted /etc/default/keyboard XKBLAYOUT "$x11_layout"
        set_kv_quoted /etc/default/keyboard XKBVARIANT "$x11_variant"
        set_kv_quoted /etc/default/keyboard XKBMODEL "pc105"
        set_kv_quoted /etc/default/keyboard XKBOPTIONS ""
        persistent_set=1
        echo "Updated /etc/default/keyboard."
        if command_exists setupcon; then
            sudo setupcon || true
        fi
    fi

    # Void (runit) reads KEYMAP from rc.conf
    if [ "$DISTRO" = void ] && [ -f /etc/rc.conf ]; then
        set_kv_unquoted /etc/rc.conf KEYMAP "$tty_keymap"
        persistent_set=1
        echo "Updated /etc/rc.conf."
    fi

    # OpenRC (Artix-openrc, Alpine/postmarketOS)
    if [ -f /etc/conf.d/keymaps ]; then
        set_kv_quoted /etc/conf.d/keymaps keymap "$tty_keymap"
        persistent_set=1
        echo "Updated /etc/conf.d/keymaps."
    fi

    # vconsole.conf: keep it in sync if it exists; create it only when nothing
    # above could persist the keymap (Artix runit/s6/dinit, minimal systems).
    if [ -f /etc/vconsole.conf ] || [ "$persistent_set" -eq 0 ]; then
        set_kv_unquoted /etc/vconsole.conf KEYMAP "$tty_keymap"
        persistent_set=1
        echo "Updated /etc/vconsole.conf."
    fi

    echo "Keyboard layout persistence configured."
}

# NOPASSWD shutdown/reboot for this user (keybinds and power menus call
# `sudo shutdown`/`sudo reboot`). Drop-in under sudoers.d, validated with
# visudo first; never touches /etc/sudoers itself. Opt out with
# PIERCINGXX_POWER_SUDOERS=0.
install_power_sudoers() {
    if [ "${PIERCINGXX_POWER_SUDOERS:-1}" = 0 ] || [ "${PIERCINGXX_NO_POWER_SUDOERS:-0}" = 1 ]; then
        echo "Skipping power sudoers drop-in (opted out)."
        return 0
    fi
    command_exists sudo || return 0
    command_exists visudo || { warn "visudo not found; skipping power sudoers drop-in."; return 0; }
    [ -d /etc/sudoers.d ] || return 0

    local dropin=/etc/sudoers.d/piercingxx-power tmp cmd
    tmp="$(mktemp)"
    {
        echo "# Managed by PiercingXX install.sh: passwordless shutdown/reboot for $username"
        for cmd in /sbin/shutdown /sbin/reboot /usr/sbin/shutdown /usr/sbin/reboot /usr/bin/shutdown /usr/bin/reboot; do
            [ -x "$cmd" ] || continue
            echo "$username ALL=NOPASSWD: $cmd"
        done
    } > "$tmp"
    if sudo visudo -cf "$tmp" >/dev/null 2>&1; then
        sudo install -m 0440 "$tmp" "$dropin"
        echo "Installed $dropin."
    else
        warn "Rejected invalid sudoers drop-in; left sudoers untouched."
    fi
    rm -f "$tmp"
}

# ---------------------------------------------------------------------------
# Which dots/ entries are ~/.config dotfiles. These are repo-only (not
# config for an app in ~/.config) and are never copied:
#   ollama  - modelfiles, used with `ollama create -f`
# ---------------------------------------------------------------------------
DOTS_SKIP=(ollama fastfetch)

dot_is_skipped() {
    local d="$1" s
    for s in "${DOTS_SKIP[@]}"; do
        [ "$d" = "$s" ] && return 0
    done
    return 1
}

# Back up everything this run will overwrite into one tarball
backup_existing() {
    local backup_dir="$home_dir/.local/state/piercingxx/backups"
    local stamp archive
    local -a targets=()
    stamp="$(date +%Y%m%d-%H%M%S)"
    archive="$backup_dir/piercing-dots-$stamp.tar.gz"

    [ -e "$home_dir/.scripts" ] && targets+=(".scripts")
    [ -e "$home_dir/.bashrc" ] && targets+=(".bashrc")
    [ -e "$home_dir/.tmux.conf" ] && targets+=(".tmux.conf")
    [ -e "$home_dir/.config/fastfetch" ] && targets+=(".config/fastfetch")
    local dot_path name
    for dot_path in dots/*; do
        name="$(basename "$dot_path")"
        dot_is_skipped "$name" && continue
        [ -e "$home_dir/.config/$name" ] && targets+=(".config/$name")
    done
    [ ${#targets[@]} -gt 0 ] || return 0

    run_as_user mkdir -p "$backup_dir"
    if run_as_user tar -czf "$archive" -C "$home_dir" --ignore-failed-read "${targets[@]}" 2>/dev/null; then
        echo "Backed up existing config to $archive"
    else
        warn "Backup to $archive reported errors (continuing; partial archive kept)."
    fi
    # Keep the 10 newest backups
    ls -1t "$backup_dir"/piercing-dots-*.tar.gz 2>/dev/null | tail -n +11 | while read -r old; do
        rm -f "$old"
    done
}

backup_existing

#Create necessary directories and copy configuration files
    # Replace .bashrc
        cp -f resources/bash/.bashrc "$home_dir"/.bashrc
        chown "$username":"$user_group" "$home_dir"/.bashrc
        echo "Replaced .bashrc."
    # Copy .tmux.conf
        cp -f resources/tmux/.tmux.conf "$home_dir"/.tmux.conf
        chown "$username":"$user_group" "$home_dir"/.tmux.conf
        echo "Copied .tmux.conf."
        # Clone TPM if it doesn't exist, then install plugins (only when tmux is present)
        if command_exists tmux && command_exists git; then
            if [ ! -d "$home_dir/.tmux/plugins/tpm" ]; then
                run_as_user mkdir -p "$home_dir/.tmux/plugins"
                run_as_user git clone --depth 1 https://github.com/tmux-plugins/tpm "$home_dir/.tmux/plugins/tpm"
            fi
            if [ -x "$home_dir/.tmux/plugins/tpm/bin/install_plugins" ]; then
                run_as_user "$home_dir/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 \
                    && echo "Installed Tmux plugins." \
                    || warn "TPM plugin install reported errors."
            fi
        else
            echo "tmux not installed; skipping TPM."
        fi
    # Update scripts: replace only the folders the rice ships, keep anything else in ~/.scripts
        sudo install -d -o "$username" -g "$user_group" "$home_dir"/.scripts
        for script_dir in resources/.scripts/*/; do
            script_dir="${script_dir%/}"
            rm -rf "${home_dir}/.scripts/$(basename "$script_dir")"
            cp -Rf "$script_dir" "$home_dir"/.scripts/
        done
        sudo chown -R "$username":"$user_group" "$home_dir"/.scripts
        # Executable bit only on scripts (*.sh and extension-less files), not html/md
        find "$home_dir"/.scripts -type f \( -name '*.sh' -o ! -name '*.*' \) -exec chmod +x {} +
        echo "Updated .scripts directory."
    # Ensure parent directories have correct ownership
        sudo install -d -o "$username" -g "$user_group" "$home_dir/.local" "$home_dir/.local/share" "$home_dir/.local/bin" "$home_dir/.config"
    # .font directory
        if [ ! -d "$home_dir/.fonts" ]; then
            sudo install -d -o "$username" -g "$user_group" "$home_dir/.fonts"
        fi
    # .icons directory
        if [ ! -d "$home_dir/.icons" ]; then
            sudo install -d -o "$username" -g "$user_group" "$home_dir/.icons"
        fi
    # Background and Profile Image Directories
        if [ ! -d "$home_dir/Pictures/backgrounds" ]; then
            sudo install -d -o "$username" -g "$user_group" "$home_dir/Pictures" "$home_dir/Pictures/backgrounds"
        fi
        if [ ! -d "$home_dir/Pictures/profile-image" ]; then
            sudo install -d -o "$username" -g "$user_group" "$home_dir/Pictures" "$home_dir/Pictures/profile-image"
        fi
    # fstab external drive mount points (linux-mod creates these on full installs)
        if [ "${PIERCINGXX_CREATE_MEDIA_DIRS:-0}" = 1 ]; then
            for media_dir in "$PX_WORK_ROOT" "$PX_ARCHIVE_ROOT"; do
                if [ ! -d "$media_dir" ]; then
                    sudo mkdir -p "$media_dir"
                    sudo chown "$username":"$user_group" "$media_dir"
                fi
            done
        fi
        echo "Created necessary directories."
    # Copy Piercing Dots config into user's .config
        sudo install -d -o "$username" -g "$user_group" "$home_dir/.config"
        sudo rm -rf "$home_dir/.config/fastfetch"
        sudo install -d -o "$username" -g "$user_group" "$home_dir/.config/fastfetch"
        for dot_path in dots/*; do
            dot_is_skipped "$(basename "$dot_path")" && continue
            cp -Rf "$dot_path" "$home_dir"/.config/
        done
        install -Dm644 dots/fastfetch/config.jsonc "$home_dir/.config/fastfetch/config.jsonc"
        # Older installs copied a full xdg-desktop-portal.service that shadows the
        # packaged unit; the repo now ships only a drop-in, so remove the stale copy.
        stale_portal="$home_dir/.config/systemd/user/xdg-desktop-portal.service"
        if [ -f "$stale_portal" ] && [ ! -e dots/systemd/user/xdg-desktop-portal.service ] \
            && grep -q 'xdg-desktop-portal' "$stale_portal"; then
            rm -f "$stale_portal"
            echo "Removed stale ~/.config/systemd/user/xdg-desktop-portal.service (backed up)."
        fi
        sudo chown -R "$username":"$user_group" "$home_dir"/.config
        echo "Copied Piercing Dots Config Files."
        if [ "$EUID" -ne 0 ] && [ -n "${XDG_RUNTIME_DIR:-}" ] && systemctl --user show-environment >/dev/null 2>&1; then
            systemctl --user daemon-reload
            systemctl --user restart xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service >/dev/null 2>&1 || true
            systemctl --user restart xdg-desktop-portal.service >/dev/null 2>&1 || \
                systemctl --user start xdg-desktop-portal.service >/dev/null 2>&1 || true
            echo "Reloaded user systemd units and refreshed xdg-desktop-portal."
        fi
    # FZF shell integration: .bashrc sources /usr/share/fzf/key-bindings.bash.
    # Arch's fzf package ships it there; Debian/Fedora/Void put it elsewhere,
    # so only fill in files the package didn't provide.
        if [ -d /usr/share/fzf/fzf ] && [ -f /usr/share/fzf/fzf/key-bindings.bash ] \
            && ! { command_exists pacman && pacman -Qoq /usr/share/fzf/fzf >/dev/null 2>&1; }; then
            # Leftover from an older install that copied the folder into itself
            sudo rm -rf /usr/share/fzf/fzf
        fi
        sudo install -d -m 755 /usr/share/fzf
        for fzf_file in resources/fzf/*; do
            fzf_target="/usr/share/fzf/$(basename "$fzf_file")"
            [ -e "$fzf_target" ] && continue
            sudo install -m 644 "$fzf_file" "$fzf_target"
            echo "Installed $fzf_target"
        done
    # Deploy greetd config (only when greetd + tuigreet are installed)
        if { command_exists greetd || [ -d /etc/greetd ]; } && command_exists tuigreet; then
            sudo install -d -m 755 /etc/greetd
            if [ -f /etc/greetd/config.toml ] && ! cmp -s /etc/greetd/config.toml resources/greetd/config.toml; then
                sudo cp -f /etc/greetd/config.toml /etc/greetd/config.toml.bak
            fi
            sudo install -m 644 resources/greetd/config.toml /etc/greetd/config.toml
            echo "Deployed greetd config to /etc/greetd/config.toml."
        else
            echo "greetd/tuigreet not installed; skipping greetd config."
        fi
    # Set keyboard layout (distro-agnostic). Colemak is the default; override with env.
        set_keyboard_layout "${PIERCINGXX_KEYMAP:-colemak}" "${PIERCINGXX_XKB_LAYOUT:-us}" "${PIERCINGXX_XKB_VARIANT:-colemak}"
    # Copy Backgrounds
        cp -Rf resources/backgrounds/* "$home_dir"/Pictures/backgrounds
        sudo chown -R "$username":"$user_group" "$home_dir"/Pictures/backgrounds
        cp -Rf resources/profile-image/* "$home_dir"/Pictures/profile-image
        sudo chown -R "$username":"$user_group" "$home_dir"/Pictures/profile-image
        echo "Copied Backgrounds and Profile Images."
    # Copy Refs to Download folder
        run_as_user mkdir -p "$home_dir"/Downloads
        for ref in resources/refs/*; do
            [ -e "$ref" ] || continue
            cp -Rf "$ref" "$home_dir"/Downloads/
            sudo chown -R "$username":"$user_group" "$home_dir/Downloads/$(basename "$ref")"
        done
        echo "Copied reference files to Downloads."
    # Install Black Minimalistic cursor theme for Linux desktops (as the user, into their $HOME)
        (cd scripts && chmod u+x install-black-minimalistic-cursor.sh && run_as_user env HOME="$home_dir" ./install-black-minimalistic-cursor.sh) \
            && echo "Installed Black Minimalistic cursor theme." \
            || warn "Cursor theme install reported errors."
    # Apply Piercing Gnome Customizations
        if [ "${PIERCINGXX_SKIP_GNOME:-0}" = 1 ]; then
            echo "Skipping GNOME customizations (PIERCINGXX_SKIP_GNOME=1)."
        elif can_apply_gnome_customizations; then
            (cd scripts && chmod u+x gnome-customizations.sh && run_as_user ./gnome-customizations.sh) \
                && echo "Applied Piercing Gnome Customizations." \
                || warn "gnome-customizations.sh reported errors."
        else
            echo "Skipping GNOME customizations during install; no active GNOME session bus/display."
            echo "Run scripts/gnome-customizations.sh after logging into GNOME."
        fi
    # Set Boot Beep (on by default; opt out with PIERCINGXX_BOOT_BEEP=0)
        if [ "${PIERCINGXX_BOOT_BEEP:-1}" != 0 ]; then
            if { [ -d /sys/firmware/efi/efivars ] && [ -d /boot/loader ]; } || grep -qi grub /proc/cmdline || [ -f /etc/default/grub ]; then
                echo -e "${YELLOW}Setting Boot Beep...${NC}"
                (cd scripts && chmod u+x set_boot_beep.sh && ./set_boot_beep.sh) \
                    && echo -e "${GREEN}Boot Beep Set successfully!${NC}" \
                    || warn "set_boot_beep.sh reported errors."
            else
                echo -e "${YELLOW}Bootloader not detected; skipping Boot Beep.${NC}"
            fi
        else
            echo "Skipping Boot Beep (PIERCINGXX_BOOT_BEEP=0)."
        fi
    # Passwordless shutdown/reboot drop-in (opt out with PIERCINGXX_POWER_SUDOERS=0)
        install_power_sudoers
    # Set PRETTY_NAME in /etc/os-release
        if [ "${PIERCINGXX_SET_PRETTY_NAME:-1}" = 1 ]; then
            pretty_name
        fi
    # Ollama install (manual: scripts/ollama-setup.sh)
    # SFP+ Fiberoptic Card Lockout Fix (only on machines with an Intel ixgbe NIC)
        sfp_fix="${PIERCINGXX_SFP_FIX:-auto}"
        if [ "$sfp_fix" = auto ]; then
            if command_exists lspci && lspci -k 2>/dev/null | grep -qE 'Kernel (driver in use|modules):.*\bixgbe\b'; then
                sfp_fix=1
            else
                sfp_fix=0
            fi
        fi
        if [ "$sfp_fix" = 1 ]; then
            echo -e "${YELLOW}Applying SFP Fiber Lockout Fix...${NC}"
            (cd scripts && chmod u+x sfp-fiber-lockout-fix.sh && sudo ./sfp-fiber-lockout-fix.sh --apply) \
                && echo -e "${GREEN}SFP Fiber Lockout Fix applied successfully!${NC}" \
                || warn "sfp-fiber-lockout-fix.sh reported errors."
        else
            echo "No ixgbe NIC found; skipping SFP Fiber Lockout Fix."
        fi
    # Strip Cursor/Claude/Grok Co-authored-by trailers on commit (Skippy stays)
        echo -e "${YELLOW}Installing git vendor-trailer hook...${NC}"
        (cd scripts && chmod u+x install-git-vendor-trailer-hook.sh && run_as_user env HOME="$home_dir" ./install-git-vendor-trailer-hook.sh) \
            && echo -e "${GREEN}Git vendor-trailer hook installed.${NC}" \
            || warn "install-git-vendor-trailer-hook.sh reported errors."
