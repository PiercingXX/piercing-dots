#!/usr/bin/env bash
# GitHub.com/PiercingXX

# Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "Cannot detect distribution!"
    exit 1
fi

# Check/install gum if missing
if ! command -v gum &> /dev/null; then
	echo "gum not found. Installing..."
	if command -v pacman &> /dev/null; then
		sudo pacman -S --noconfirm gum
	elif command -v apt &> /dev/null; then
		sudo apt update && sudo apt install -y gum
	elif command -v dnf &> /dev/null; then
		sudo dnf install -y gum
	else
		echo "Please install gum manually."
		exit 1
	fi
fi

	options=(
		"🚀 Update System"
		"📦 Terminal Software Manager"
		"🎤 Audio Input Manager"
		"📶 WiFi Manager"
		"🔵 Bluetooth Manager"
		"🖼️ Change Wallpaper"
		"🗄️ Backup & Restore"
		"👤 User Management"
		"✨ Update PiercingXX Rice"
		"🚪 Quit"
	)
	if [[ "$DISTRO" == "arch" ]]; then
		options=(
			"🚀 Update System"
			"📦 Terminal Software Manager"
			"🎤 Audio Input Manager"
			"📶 WiFi Manager"
			"🔵 Bluetooth Manager"
			"🖼️ Change Wallpaper"
			"🗄️ Backup & Restore"
			"👤 User Management"
			"✨ Update PiercingXX Rice"
			"🌐 Update Mirrors"
			"🚪 Quit"
		)
	fi

	choice=$(printf "%s\n" "${options[@]}" | gum choose --header="PiercingXX - Settings Menu")
	case "$choice" in
			"🚀 Update System")
				~/.scripts/update-system.sh
				;;
			"📦 Terminal Software Manager")
				~/.scripts/terminal-software-manager.sh
				;;
			"🌐 Update Mirrors")
				~/.scripts/update-mirrors.sh
				;;
			"✨ Update PiercingXX Rice")
				~/.scripts/update-piercingXX.sh
				;;
			"🖼️ Change Wallpaper")
				~/.scripts/change-wallpaper.sh
				;;
			"📶 WiFi Manager")
				~/.scripts/wifi-manager.sh
				;;
			"🔵 Bluetooth Manager")
				~/.scripts/bluetooth-manager.sh
				;;
			"👤 User Management")
				~/.scripts/user-management.sh
				;;
			"🗄️ Backup & Restore")
				~/.scripts/backup-restore.sh
				;;
            "🎤 Audio Input Manager")
                ~/.scripts/audio-input-manager.sh
                ;;
			"🚪 Quit"|"")
				clear
				exit 0
				;;
		esac