#!/usr/bin/env bash
# GitHub.com/PiercingXX

# Settings Menu TUI

while true; do
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
		choice=$(gum choose --header="Settings Menu" \
			"🚀 Update & Clean" \
			"📦 Terminal Software Manager" \
			"📶 WiFi Manager" \
			"🔵 Bluetooth Manager" \
			"👤 User Management" \
			"🗄️ Backup & Restore" \
			"🚪 Quit")
	case "$choice" in
			"🚀 Update & Clean")
				~/.scripts/maintenance.sh
				;;
			"📦 Terminal Software Manager")
				~/.scripts/terminal_software_manager.sh
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
				exit 0
				;;
	esac
done
