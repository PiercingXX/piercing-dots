#!/bin/bash


# Function to get the current volume as a number
get_current_volume() {
    pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -1 | tr -d '%'
}

# Check command line arguments
if [[ "$#" != 1 || ! ("$1" == "inc" || "$1" == "dec" || "$1" == "mute" ) ]]; then
    printf "Usage: $0 [inc|dec|mute]\n"
    exit 1
fi


# Function to detect distro and install packages
install_if_missing() {
    pkg="$1"
    bin="$2"
    if command -v "$bin" &> /dev/null; then
        return
    fi
    # Detect distro
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            arch|manjaro)
                sudo pacman -Sy --noconfirm "$pkg"
                ;;
            ubuntu|debian|pop)
                sudo apt-get update && sudo apt-get install -y "$pkg"
                ;;
            fedora)
                sudo dnf install -y "$pkg"
                ;;
            opensuse*)
                sudo zypper install -y "$pkg"
                ;;
            *)
                echo "Unsupported distro. Please install $pkg manually."
                exit 1
                ;;
        esac
    else
        echo "/etc/os-release not found. Please install $pkg manually."
        exit 1
    fi
}

# Ensure pactl and notify-send are installed
install_if_missing "pulseaudio" "pactl"
install_if_missing "libnotify-bin" "notify-send"

# Perform volume adjustment
if [[ "$1" == "inc" ]]; then
    pactl set-sink-volume @DEFAULT_SINK@ +5%
    action="Up"
elif [[ "$1" == "dec" ]]; then
    pactl set-sink-volume @DEFAULT_SINK@ -5%
    action="Down"
elif [[ "$1" == "mute" ]]; then
    pactl set-sink-mute @DEFAULT_SINK@ toggle
    muted=$(pactl get-sink-mute @DEFAULT_SINK@ | grep -q yes && echo "Muted" || echo "Unmuted")
    icon="audio-volume-muted"
    notify-send -a Volume -i "$icon" "🔇 Volume $muted"
    exit 0
fi

# Show notification with current volume as a bar
volume=$(get_current_volume)
# Build a bar (10 blocks max)
blocks=$((volume / 10))
bar=""
for ((i=0;i<10;i++)); do
    if (( i < blocks )); then
        bar+="█"
    else
        bar+="─"
    fi
done

# Choose icon based on volume
if (( volume == 0 )); then
    icon="audio-volume-muted"
elif (( volume < 30 )); then
    icon="audio-volume-low"
elif (( volume < 70 )); then
    icon="audio-volume-medium"
else
    icon="audio-volume-high"
fi

notify-send -a Volume -i "$icon" "🔊 Volume: $volume%" "$bar"