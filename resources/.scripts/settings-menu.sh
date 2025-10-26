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

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Reliable-ish internet check
check_internet() {
    local timeout=4
    if command_exists nm-online; then
        nm-online -q -t "$timeout" && return 0
    fi
    if command_exists networkctl; then
        networkctl -q is-online --timeout="$timeout" && return 0
    fi
    local urls=(
        "https://connectivitycheck.gstatic.com/generate_204"
        "http://www.google.com/generate_204"
        "http://www.msftncsi.com/ncsi.txt"
        "http://www.msftconnecttest.com/connecttest.txt"
    )
    for url in "${urls[@]}"; do
        local code
        code=$(curl -4 -fsS --max-time "$timeout" -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || true)
        if [[ "$code" == "204" ]]; then
            return 0
        fi
        if [[ "$code" == "200" && "$url" == *"msft"* ]]; then
            local body
            body=$(curl -4 -fsS --max-time "$timeout" "$url" 2>/dev/null | tr -d '\r\n')
            if [[ "$body" == "Microsoft NCSI" || "$body" == "Microsoft Connect Test" ]]; then
                return 0
            fi
        fi
    done
    local hosts=(1.1.1.1 8.8.8.8 9.9.9.9)
    for host in "${hosts[@]}"; do
        if ping -4 -c 1 -W 1 "$host" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

# Require internet before continuing
if ! check_internet; then
    echo "Internet connectivity is required to continue."
    exit 1
fi






# Check/install gum if missing
if ! command -v gum &> /dev/null; then
    echo "gum not found. Installing..."
    if command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm gum
    else
        echo "Please install gum manually."
        exit 1
    fi
fi











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
		"🎤 Audio Input Manager"
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
			"🎤 Audio Input Manager"
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
				~/.scripts/terminal-software-manager.sh
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
done
