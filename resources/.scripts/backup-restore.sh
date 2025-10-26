#!/usr/bin/env bash
# GitHub.com/PiercingXX

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Auto-install rsync if missing
if ! command_exists rsync; then
    echo -e "${yellow}rsync not found – attempting install...${nc}"
    case "$DISTRO" in
        arch)
            sudo pacman -S --noconfirm rsync ;;
        fedora)
            sudo dnf install -y rsync >/dev/null 2>&1 ;;
        debian|ubuntu|pop|linuxmint|mint)
            sudo apt install -y rsync >/dev/null 2>&1 ;;
        *)
            echo -e "${yellow}Unsupported distro for auto rsync install. Skipping.${nc}"
            ;;
    esac
    if command_exists rsync; then
        echo -e "${green}rsync installed successfully.${nc}"
    else
        echo -e "${yellow}Could not install rsync; will full replace config.${nc}"
    fi
fi



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
