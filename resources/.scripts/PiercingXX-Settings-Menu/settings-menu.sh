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
	elif command -v xbps-install &> /dev/null; then
		sudo xbps-install -Sy gum
	else
		echo "Please install gum manually."
		exit 1
	fi
fi

use_ascii_menu=0
if [[ ${PIERCINGXX_ASCII_MENU:-0} == 1 ]] || [[ -t 1 && ${TERM:-} == "linux" ]]; then
	use_ascii_menu=1
fi

options=()
actions=()

add_option() {
	options+=("$1")
	actions+=("$2")
}

if [[ $use_ascii_menu -eq 1 ]]; then
	add_option "> Update System" "update_system"
	add_option "> Terminal Software Manager" "terminal_software_manager"
	add_option "> Audio Input Manager" "audio_input_manager"
	add_option "> WiFi Manager" "wifi_manager"
	add_option "> Bluetooth Manager" "bluetooth_manager"
	add_option "> Change Wallpaper" "change_wallpaper"
	add_option "> Backup & Restore" "backup_restore"
	add_option "> User Management" "user_management"
	add_option "> Update PiercingXX Rice" "update_piercingxx"
	if [[ "$DISTRO" == "arch" ]]; then
		add_option "> Update Mirrors" "update_mirrors"
		add_option "> Virus Scan" "virus_scan"
		add_option "> Clean System" "clean_system"
		add_option "> Quit" "quit"
	else
		add_option "> Virus Scan" "virus_scan"
		add_option "> Clean System" "clean_system"
		add_option "> Quit" "quit"
	fi
else
	add_option "🚀 Update System" "update_system"
	add_option "📦 Terminal Software Manager" "terminal_software_manager"
	add_option "🎤 Audio Input Manager" "audio_input_manager"
	add_option "📶 WiFi Manager" "wifi_manager"
	add_option "🔵 Bluetooth Manager" "bluetooth_manager"
	add_option "🖼️ Change Wallpaper" "change_wallpaper"
	add_option "🗄️ Backup & Restore" "backup_restore"
	add_option "👤 User Management" "user_management"
	add_option "✨ Update PiercingXX Rice" "update_piercingxx"
	if [[ "$DISTRO" == "arch" ]]; then
		add_option "🌐 Update Mirrors" "update_mirrors"
	fi
	add_option "🛡️ Virus Scan" "virus_scan"
	add_option "🧹 Clean System" "clean_system"
	add_option "🚪 Quit" "quit"
fi

while true; do
	# Build searchable menu with descriptions
	menu_list=()
	for opt in "${options[@]}"; do
		menu_list+=("$opt")
	done
	selected=$(printf "%s\n" "${menu_list[@]}" | gum filter --header="PiercingXX - Settings Menu (type to search)" --placeholder="Search or select an option...")
	action=""
	for i in "${!options[@]}"; do
		if [[ "${options[$i]}" == "$selected" ]]; then
			action="${actions[$i]}"
			break
		fi
	done
	case "$action" in
		update_system)
			bash ~/.scripts/PiercingXX-Settings-Menu/update-system.sh
			;;
		terminal_software_manager)
			bash ~/.scripts/PiercingXX-Settings-Menu/terminal-software-manager.sh
			;;
		update_mirrors)
			bash ~/.scripts/PiercingXX-Settings-Menu/update-mirrors.sh
			;;
		update_piercingxx)
			bash ~/.scripts/PiercingXX-Settings-Menu/update-piercingXX.sh
			;;
		change_wallpaper)
			bash ~/.scripts/PiercingXX-Settings-Menu/change-wallpaper.sh
			;;
		wifi_manager)
			bash ~/.scripts/PiercingXX-Settings-Menu/wifi-manager.sh
			;;
		bluetooth_manager)
			bash ~/.scripts/PiercingXX-Settings-Menu/bluetooth-manager.sh
			;;
		user_management)
			bash ~/.scripts/PiercingXX-Settings-Menu/user-management.sh
			;;
		backup_restore)
			bash ~/.scripts/PiercingXX-Settings-Menu/backup-restore.sh
			;;
		audio_input_manager)
			bash ~/.scripts/PiercingXX-Settings-Menu/audio-input-manager.sh
			;;
		virus_scan)
			bash ~/.scripts/PiercingXX-Settings-Menu/virus-scan.sh
			;;
		clean_system)
			bash ~/.scripts/PiercingXX-Settings-Menu/clean-system.sh
			;;
		quit|"")
			clear
			exit 0
			;;
	esac
	echo
done
