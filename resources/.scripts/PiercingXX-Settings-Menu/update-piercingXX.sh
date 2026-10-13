#!/bin/bash
# GitHub.com/PiercingXX
# Re-apply the PiercingXX rice from the latest piercing-dots on GitHub.
# Clones into a private temp dir, shows what would change, backs up the
# current configs, then runs the repo's install.sh.

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

refuse_root

REPO_URL="https://github.com/Piercingxx/piercing-dots.git"
BACKUP_ROOT="$PX_STATE_DIR/backups"
KEEP_BACKUPS=5

WORK_DIR=""
CLONE_DIR=""

cleanup_clone() {
    [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"
    WORK_DIR=""
    CLONE_DIR=""
}
trap cleanup_clone EXIT

check_internet() {
    local url code
    if command_exists nm-online && nm-online -q -t 4; then
        return 0
    fi
    for url in https://connectivitycheck.gstatic.com/generate_204 http://www.google.com/generate_204; do
        code=$(curl -4 -fsS --max-time 4 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)
        [ "$code" = 204 ] && return 0
    done
    # GitHub itself is what we actually need
    curl -fsS --max-time 6 -o /dev/null https://github.com 2>/dev/null && return 0
    return 1
}

ensure_gum() {
    command_exists gum && return 0
    say "gum not found. Installing..."
    detect_distro
    pkg_install gum >/dev/null 2>&1 && command_exists gum
}

choose() {
    local header="$1"; shift
    if command_exists gum; then
        printf '%s\n' "$@" | gum choose --header "$header" --cursor.foreground 212 --selected.foreground 212
    else
        local opt
        PS3="$header > "
        select opt in "$@"; do
            [ -n "$opt" ] && { echo "$opt"; return 0; }
        done
    fi
}

# Fresh shallow clone into a private temp dir (never the caller's cwd)
clone_rice() {
    cleanup_clone
    WORK_DIR=$(mktemp -d) || return 1
    CLONE_DIR="$WORK_DIR/piercing-dots"
    say "Downloading piercing-dots..."
    if ! git clone --quiet --depth 1 "$REPO_URL" "$CLONE_DIR"; then
        err "Could not clone $REPO_URL"
        cleanup_clone
        return 1
    fi
    chmod -R u+x "$CLONE_DIR/install.sh" "$CLONE_DIR/scripts" 2>/dev/null || true
}

# List files install.sh would add or change (checksum compare, no writes)
preview_changes() {
    local skip_hypr="${1:-0}" out
    command_exists rsync || { warn "rsync not installed; skipping preview."; return 0; }
    local -a excludes=()
    [ "$skip_hypr" = 1 ] && excludes=(--exclude '/hypr/')
    out=$(
        {
            rsync -rcn --itemize-changes "${excludes[@]}" "$CLONE_DIR/dots/" "$HOME/.config/" \
                | awk '$1 ~ /^>f/ {print "~/.config/" $2}'
            rsync -rcn --itemize-changes "$CLONE_DIR/resources/.scripts/" "$HOME/.scripts/" \
                | awk '$1 ~ /^>f/ {print "~/.scripts/" $2}'
            cmp -s "$CLONE_DIR/resources/bash/.bashrc" "$HOME/.bashrc" || echo "~/.bashrc"
            cmp -s "$CLONE_DIR/resources/tmux/.tmux.conf" "$HOME/.tmux.conf" || echo "~/.tmux.conf"
        } 2>/dev/null
    )
    if [ -z "$out" ]; then
        ok "Your configs already match the latest rice."
        return 0
    fi
    say "$(printf '%s\n' "$out" | wc -l) file(s) will be added or overwritten:"
    if command_exists gum && [ -t 1 ]; then
        printf '%s\n' "$out" | gum pager
    else
        printf '%s\n' "$out" | head -n 60
        [ "$(printf '%s\n' "$out" | wc -l)" -gt 60 ] && echo "..."
    fi
}

# Copy everything install.sh overwrites into a timestamped backup
backup_current() {
    local ts dest name
    ts=$(date +%Y%m%d-%H%M%S)
    dest="$BACKUP_ROOT/rice-$ts"
    mkdir -p "$dest/config"
    for path in "$CLONE_DIR"/dots/*; do
        name=$(basename "$path")
        [ -e "$HOME/.config/$name" ] || continue
        cp -a "$HOME/.config/$name" "$dest/config/" 2>/dev/null
    done
    [ -d "$HOME/.scripts" ] && cp -a "$HOME/.scripts" "$dest/scripts"
    for f in .bashrc .tmux.conf; do
        [ -f "$HOME/$f" ] && cp -a "$HOME/$f" "$dest/"
    done
    ok "Backed up current configs to $dest"

    # Keep only the newest backups
    find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'rice-*' -printf '%f\n' 2>/dev/null \
        | sort -r | tail -n +$((KEEP_BACKUPS + 1)) \
        | while read -r old; do rm -rf "${BACKUP_ROOT:?}/$old"; done
}

restore_backup() {
    local -a backups
    mapfile -t backups < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'rice-*' -printf '%f\n' 2>/dev/null | sort -r)
    if [ ${#backups[@]} -eq 0 ]; then
        warn "No backups found in $BACKUP_ROOT"
        return 1
    fi
    local pick
    pick=$(choose "Restore which backup?" "${backups[@]}" "Cancel")
    [ -z "$pick" ] || [ "$pick" = "Cancel" ] && return 0
    local src="$BACKUP_ROOT/$pick"
    confirm "Restore $pick over your current ~/.config, ~/.scripts and dotfiles?" || return 0
    [ -d "$src/config" ] && cp -a "$src/config/." "$HOME/.config/"
    [ -d "$src/scripts" ] && cp -a "$src/scripts/." "$HOME/.scripts/"
    for f in .bashrc .tmux.conf; do
        [ -f "$src/$f" ] && cp -a "$src/$f" "$HOME/$f"
    done
    ok "Restored $pick."
}

# apply_rice [skip_hypr]
apply_rice() {
    local skip_hypr="${1:-0}"
    clone_rice || return 1
    preview_changes "$skip_hypr"
    if ! confirm "Apply the PiercingXX rice now?"; then
        say "Nothing changed."
        cleanup_clone
        return 0
    fi
    backup_current
    if [ "$skip_hypr" = 1 ]; then
        # Keep your hypr config, but still take the rice's keybinds.lua
        mkdir -p "$HOME/.config/hypr/hyprland"
        if [ -f "$CLONE_DIR/dots/hypr/hyprland/keybinds.lua" ]; then
            cp -pf "$CLONE_DIR/dots/hypr/hyprland/keybinds.lua" "$HOME/.config/hypr/hyprland/"
        fi
        rm -rf "$CLONE_DIR/dots/hypr"
    fi
    if (cd "$CLONE_DIR" && ./install.sh); then
        ok "PiercingXX Rice Applied Successfully!"
    else
        warn "install.sh reported errors. Your previous configs are in $BACKUP_ROOT."
    fi
    cleanup_clone
}

if ! check_internet; then
    die "Network connectivity is required to continue."
fi
command_exists git || die "git is required."
ensure_gum || warn "gum unavailable; using a plain menu."

while true; do
    [ -t 1 ] && clear
    choice=$(choose "PiercingXX Update Options" \
        "Apply PiercingXX - Everything" \
        "Apply PiercingXX - Gimp Only" \
        "Apply PiercingXX - without Hyprland configs" \
        "Apply PiercingXX - Gnome Customizations ONLY" \
        "Preview changes only" \
        "Restore a previous backup" \
        "Exit")
    case $choice in
        "Apply PiercingXX - Everything")
            say "Downloading and Applying PiercingXX Rice..."
            apply_rice 0
            ;;
        "Apply PiercingXX - Gimp Only")
            say "Installing PiercingXX - Gimp Presets..."
            if clone_rice; then
                (cd "$CLONE_DIR/scripts" && ./gimp-mod.sh) && ok "Piercing Gimp Presets Installed Successfully!"
                cleanup_clone
            fi
            ;;
        "Apply PiercingXX - without Hyprland configs")
            say "Downloading and Applying PiercingXX Rice w/o Hyprdots..."
            apply_rice 1
            ;;
        "Apply PiercingXX - Gnome Customizations ONLY")
            say "Applying PiercingXX - Gnome Customizations ONLY..."
            if clone_rice; then
                (cd "$CLONE_DIR/scripts" && chmod u+x gnome-customizations.sh && ./gnome-customizations.sh)
                cleanup_clone
            fi
            ;;
        "Preview changes only")
            if clone_rice; then
                preview_changes 0
                cleanup_clone
            fi
            ;;
        "Restore a previous backup")
            restore_backup
            ;;
        "Exit"|"")
            [ -t 1 ] && clear
            exit 0
            ;;
    esac
    pause
done
