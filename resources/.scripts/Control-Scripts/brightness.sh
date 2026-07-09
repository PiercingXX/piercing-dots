#!/bin/bash


# Function to detect distro and install packages
install_if_missing() {
  pkg="$1"
  bin="$2"
  if command -v "$bin" &> /dev/null; then
    return
  fi
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

# Ensure brightnessctl is installed
install_if_missing "brightnessctl" "brightnessctl"

NOTIFY_ID=99971
QUICK_TIMEOUT=1100

if command -v dunstify &>/dev/null; then
  NOTIFY_BIN="dunstify"
elif command -v notify-send &>/dev/null; then
  NOTIFY_BIN="notify-send"
  notify-send --help 2>&1 | grep -q -- '--replace-id' && NOTIFY_REPLACE=true || NOTIFY_REPLACE=false
else
  echo "No notification backend found (need dunstify or notify-send)." >&2
  exit 1
fi

notify_brightness_msg() {
  local summary="$1" body="$2" icon="$3"
  if [[ "$NOTIFY_BIN" == "dunstify" ]]; then
    dunstify -r "$NOTIFY_ID" -u low -t "$QUICK_TIMEOUT" -a Brightness -i "$icon" "$summary" "$body"
  elif [[ "${NOTIFY_REPLACE:-false}" == true ]]; then
    notify-send --replace-id="$NOTIFY_ID" -u low -t "$QUICK_TIMEOUT" -a Brightness -i "$icon" "$summary" "$body"
  else
    notify-send -u low -t "$QUICK_TIMEOUT" -a Brightness -i "$icon" -h "string:x-dunst-stack-tag:brightness-notify" "$summary" "$body"
  fi
}

# Function to show brightness notification with icon and bar
notify_brightness() {
  MAX_BRIGHTNESS=$(brightnessctl max)
  CURRENT_BRIGHTNESS=$(brightnessctl get)
  BRIGHTNESS_PERCENT=$((CURRENT_BRIGHTNESS * 100 / MAX_BRIGHTNESS))
  # Build a bar (10 blocks max)
  blocks=$((BRIGHTNESS_PERCENT / 10))
  bar=""
  for ((i=0;i<10;i++)); do
    if (( i < blocks )); then
      bar+="█"
    else
      bar+="─"
    fi
  done
  # Choose icon based on brightness
  if (( BRIGHTNESS_PERCENT == 0 )); then
    icon="display-brightness-off"
  elif (( BRIGHTNESS_PERCENT < 30 )); then
    icon="display-brightness-low"
  elif (( BRIGHTNESS_PERCENT < 70 )); then
    icon="display-brightness-medium"
  else
    icon="display-brightness-high"
  fi
  notify_brightness_msg "Brightness ${BRIGHTNESS_PERCENT}%" "$bar" "$icon"
}

# Check command line arguments
if [[ "$#" != 1 || ! ("$1" == "inc" || "$1" == "dec") ]]; then
    printf "Usage: %s [inc|dec]\n" "$0" >&2
    exit 1
fi



# Perform brightness adjustment
if [[ "$1" == "inc" ]]; then
  brightnessctl set +10% > /dev/null
  notify_brightness
elif [[ "$1" == "dec" ]]; then
  brightnessctl set 10%- > /dev/null
  notify_brightness
fi




