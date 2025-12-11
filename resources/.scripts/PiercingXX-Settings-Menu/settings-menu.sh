#!/bin/bash
# GitHub.com/PiercingXX

clear
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
		"🛡️ Virus Scan"
		"🧹 Clean System"
		"🚪 Quit"
	)
	if [[ "$DISTRO" == "arch" ]]; then
		# Only add Arch-specific options
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
			"🛡️ Virus Scan"
			"🧹 Clean System"
			"🚪 Quit"
		)
	fi



while true; do
	# Build searchable menu with descriptions
	menu_list=()
	for opt in "${options[@]}"; do
		menu_list+=("$opt")
	done
	selected=$(printf "%s\n" "${menu_list[@]}" | gum filter --header="PiercingXX - Settings Menu (type to search)" --placeholder="Search or select an option...")
	choice="$selected"
	case "$choice" in
		"🚀 Update System")
			bash ~/.scripts/PiercingXX-Settings-Menu/update-system.sh
			;;
		"📦 Terminal Software Manager")
			bash ~/.scripts/PiercingXX-Settings-Menu/terminal-software-manager.sh
			;;
		"🌐 Update Mirrors")
			bash ~/.scripts/PiercingXX-Settings-Menu/update-mirrors.sh
			;;
		"✨ Update PiercingXX Rice")
			bash ~/.scripts/PiercingXX-Settings-Menu/update-piercingXX.sh
			;;
		"🖼️ Change Wallpaper")
			bash ~/.scripts/PiercingXX-Settings-Menu/change-wallpaper.sh
			;;
		"📶 WiFi Manager")
			bash ~/.scripts/PiercingXX-Settings-Menu/wifi-manager.sh
			;;
		"🔵 Bluetooth Manager")
			bash ~/.scripts/PiercingXX-Settings-Menu/bluetooth-manager.sh
			;;
		"👤 User Management")
			bash ~/.scripts/PiercingXX-Settings-Menu/user-management.sh
			;;
		"🗄️ Backup & Restore")
			bash ~/.scripts/PiercingXX-Settings-Menu/backup-restore.sh
			;;
		"🎤 Audio Input Manager")
			bash ~/.scripts/PiercingXX-Settings-Menu/audio-input-manager.sh
			;;
		"🛡️ Virus Scan")
			bash ~/.scripts/PiercingXX-Settings-Menu/virus-scan.sh
			;;
		"🧹 Clean System")
			bash ~/.scripts/PiercingXX-Settings-Menu/clean-system.sh
			;;
		"🚪 Quit"|"")
			clear
			exit 0
			;;
	esac
	echo
done