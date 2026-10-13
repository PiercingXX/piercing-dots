#!/bin/bash
# GitHub.com/PiercingXX
# Backup & Restore with rsync. Every run shows a dry-run preview first.
#   Backup:  add/update by default; "mirror" (rsync --delete) is opt-in.
#   Restore: never deletes files in the destination unless you pick mirror.

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
detect_distro

command_exists gum || die "gum is required for this menu."

if ! command_exists rsync; then
    warn "rsync not found - attempting install..."
    pkg_install rsync || true
    command_exists rsync || die "rsync is required for Backup & Restore."
fi

# Expand ~ and $VARs-free input, strip trailing slashes, make absolute
normalize_path() {
    local p="$1"
    p="${p/#\~/$HOME}"
    realpath -m -- "$p"
}

pick_dir() {
    # pick_dir "header" -> existing directory (gum file browser, dotfiles shown)
    local header="$1" start="${2:-$HOME}"
    say "$header (Enter on a folder to open it, then select it)" >&2
    gum file --directory --all "$start"
}

ask_dest() {
    local header="$1" def="$2" p
    p=$(gum input --header "$header" --value "$def" --placeholder "/path/to/folder") || return 1
    [ -n "$p" ] || return 1
    normalize_path "$p"
}

# Paths we refuse as a destination: /, the top of a system tree, or $HOME for mirror mode
dangerous_dest() {
    case "$1" in
        /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/srv|/sys|/usr|/var) return 0 ;;
    esac
    return 1
}

run_sync() {
    # run_sync label src dest
    local label="$1" src="$2" dest="$3" mode
    local -a opts=(-aH --info=stats1,progress2)

    [ -d "$src" ] || { err "Source does not exist: $src"; return 1; }
    [ "$src" = "$dest" ] && { err "Source and destination are the same."; return 1; }
    if dangerous_dest "$dest"; then
        err "Refusing to use $dest as a destination."
        return 1
    fi

    mode=$(gum choose --header "$label: how should existing files in the destination be treated?" \
        "Add / update only (safe)" \
        "Mirror - also DELETE files not in the source" \
        "Cancel") || return 0
    case "$mode" in
        Cancel|"") return 0 ;;
        Mirror*)
            if [ "$dest" = "$HOME" ]; then
                err "Refusing to mirror into your whole home folder; pick a subfolder."
                return 1
            fi
            opts+=(--delete) ;;
    esac

    # Backing up into a folder inside the source would copy the backup into itself
    case "$dest/" in
        "$src"/*) opts+=(--exclude="/${dest#"$src"/}/") ;;
    esac

    if [ ! -d "$dest" ]; then
        mkdir -p "$dest" 2>/dev/null || { err "Cannot create $dest (no permission?)."; return 1; }
    elif [ ! -w "$dest" ]; then
        err "$dest is not writable by $(id -un)."
        return 1
    fi

    clear
    say "Preview (dry run): $src/ -> $dest/"
    local preview changes deletes o
    local -a preview_opts=()
    for o in "${opts[@]}"; do
        [[ "$o" == --info=* ]] || preview_opts+=("$o")
    done
    preview=$(rsync -n --itemize-changes "${preview_opts[@]}" "$src/" "$dest/" 2>&1)
    changes=$(printf '%s\n' "$preview" | grep -c '^[<>ch.]f')
    deletes=$(printf '%s\n' "$preview" | grep -c '^\*deleting')
    printf '%s\n' "$preview" | tail -n 40
    echo
    echo "Files to copy/update: $changes"
    [ "$deletes" -gt 0 ] && warn "Files to DELETE in $dest: $deletes"
    echo

    gum confirm "Run this $label now?" --default=false || { say "Cancelled."; return 0; }
    if rsync "${opts[@]}" "$src/" "$dest/"; then
        ok "$label complete."
    else
        err "$label failed - see errors above."
        return 1
    fi
}

while true; do
    clear
    action=$(gum choose --header="Backup & Restore" "Backup" "Restore" "Back")
    case "$action" in
        "Backup")
            src=$(pick_dir "Choose the folder to back up") || continue
            [ -n "$src" ] || continue
            src=$(normalize_path "$src")
            dest=$(ask_dest "Backup destination folder" "$PX_WORK_ROOT/Backups/$(basename "$src")") || continue
            run_sync "Backup" "$src" "$dest"
            pause
            ;;
        "Restore")
            src=$(pick_dir "Choose the backup folder to restore from" "$PX_WORK_ROOT") || continue
            [ -n "$src" ] || continue
            src=$(normalize_path "$src")
            dest=$(ask_dest "Restore into which folder?" "$HOME/$(basename "$src")") || continue
            run_sync "Restore" "$src" "$dest"
            pause
            ;;
        "Back"|"")
            break
            ;;
    esac
done
