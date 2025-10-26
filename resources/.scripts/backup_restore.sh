#!/usr/bin/env bash
# GitHub.com/PiercingXX

# Simple Backup & Restore App using rsync

while true; do
    if ! command -v gum &>/dev/null; then
        if command -v paru &>/dev/null; then
            echo "gum not found. Installing gum with paru..."
            paru --noconfirm -S gum
        fi
    fi
    if ! command -v gum &>/dev/null; then
        echo "gum is not installed and could not be installed automatically. Please install gum."
        exit 1
    fi
    action=$(gum choose --header="Backup & Restore" "Backup" "Restore" "Back")
    case "$action" in
        "Backup")
            src=$(gum input --placeholder="Enter source directory (to backup)")
            dest=$(gum input --placeholder="Enter backup destination directory")
            if [ -n "$src" ] && [ -n "$dest" ]; then
                if [ ! -d "$src" ]; then
                    echo "Source directory does not exist: $src"
                    echo "Press Enter to continue..."; read; continue
                fi
                mkdir -p "$dest"
                echo "Running: rsync -avh --delete '$src/' '$dest/'"
                if rsync -avh --delete "$src/" "$dest/" 2>&1; then
                    echo "Backup complete. Press Enter to continue..."
                else
                    echo "Backup failed! See errors above. Press Enter to continue..."
                fi
                read
            fi
            ;;
        "Restore")
            src=$(gum input --placeholder="Enter backup source directory (to restore from)")
            dest=$(gum input --placeholder="Enter restore destination directory")
            if [ -n "$src" ] && [ -n "$dest" ]; then
                if [ ! -d "$src" ]; then
                    echo "Backup source directory does not exist: $src"
                    echo "Press Enter to continue..."; read; continue
                fi
                mkdir -p "$dest"
                echo "Running: rsync -avh --delete '$src/' '$dest/'"
                if rsync -avh --delete "$src/" "$dest/" 2>&1; then
                    echo "Restore complete. Press Enter to continue..."
                else
                    echo "Restore failed! See errors above. Press Enter to continue..."
                fi
                read
            fi
            ;;
        "Back"|"")
            break
            ;;
    esac
    clear
    # Loop back to menu
    continue
    break
    done
