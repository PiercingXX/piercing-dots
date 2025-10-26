#!/usr/bin/env bash
# GitHub.com/PiercingXX

# Settings Menu TUI

if [ -f /etc/os-release ]; then
	. /etc/os-release
	DISTRO=$ID
else
	DISTRO="unknown"
fi

while true; do
	clear
	if ! command -v gum &>/dev/null; then
		if command -v paru &>/dev/null; then
			echo "gum not found. Installing gum with paru..."
			paru --noconfirm -S gum
		fi
	fi
	if ! command -v gum &>/dev/null; then
		echo "gum is not installed and could not be installed automatically. Please install gum for a modern menu (https://github.com/charmbracelet/gum)."
		exit 1
	fi

	options=(
		"🚀 Update System"
		"📦 Terminal Software Manager"
		"✨ Update PiercingXX Rice"
		"🖼️ Change Wallpaper"
		"📶 WiFi Manager"
		"🔵 Bluetooth Manager"
		"👤 User Management"
		"🗄️ Backup & Restore"
		"🚪 Quit"
	)
	if [[ "$DISTRO" == "arch" ]]; then
		options=(
			"🚀 Update System"
			"📦 Terminal Software Manager"
			"🌐 Update Mirrors"
			"✨ Update PiercingXX Rice"
			"🖼️ Change Wallpaper"
			"📶 WiFi Manager"
			"🔵 Bluetooth Manager"
			"👤 User Management"
			"🗄️ Backup & Restore"
			"🚪 Quit"
		)
	fi

	choice=$(printf "%s\n" "${options[@]}" | gum choose --header="Settings Menu")
	case "$choice" in
			"🚀 Update System")
				~/.scripts/update-system.sh
				;;
			"📦 Terminal Software Manager")
				~/.scripts/terminal_software_manager.sh
				;;
			"🌐 Update Mirrors")
				~/.scripts/update-mirrors.sh
				;;
			"✨ Update PiercingXX")
				~/.scripts/update-piercingXX.sh
				;;
			"🖼️ Change Wallpaper")
				~/.scripts/change-wallpaper.sh
				;;
			"📶 WiFi Manager")
				~/.scripts/wifi_manager.sh
				;;
			"🔵 Bluetooth Manager")
				~/.scripts/bluetooth_manager.sh
				;;
			"👤 User Management")
				~/.scripts/user_management.sh
				;;
			"🗄️ Backup & Restore")
				~/.scripts/backup_restore.sh
				;;
			"🚪 Quit"|"")
				clear
				exit 0
				;;
		esac
done
