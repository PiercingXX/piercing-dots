#!/bin/bash
# GitHub.com/PiercingXX

set -e

clear

# Detect audio system
audio_system=""
if command -v wpctl &>/dev/null; then
    audio_system="pipewire"
elif command -v pactl &>/dev/null; then
    audio_system="pulseaudio"
elif command -v arecord &>/dev/null; then
    audio_system="alsa"
else
    echo "No supported audio system detected (PipeWire, PulseAudio, or ALSA)." >&2
    exit 1
fi

# Constants for excluding a single unwanted sink
UNWANTED_SINK_NAME="alsa_output.pci-0000_7d_00.6.iec958-stereo"
UNWANTED_SINK_DESC="Family 17h/19h/1ah HD Audio Controller Digital Stereo (IEC958)"

# Helper: get human-friendly description for a sink name
get_sink_desc() {
    local name="$1"
    pactl list sinks | awk -v target="$name" '
        index($0, "Name: " target) {found=1}
        found && /Description:/ {sub(/^.*Description: /, ""); print; exit}
    ' | xargs
}

# --- Flag parser for --toggle-output ---
if [[ "$1" == "--toggle-output" ]]; then
    if [[ "$audio_system" == "pipewire" || "$audio_system" == "pulseaudio" ]]; then
        # Build list of allowed sinks (skip only the exact unwanted sink by name/description)
        sinks=()
        sink_descs=()
        while IFS= read -r line; do
            sink_name=$(echo "$line" | awk '{print $2}')
            desc=$(get_sink_desc "$sink_name")
            if [[ "$sink_name" == "$UNWANTED_SINK_NAME" ]] || [[ "$desc" == "$UNWANTED_SINK_DESC" ]]; then
                continue
            fi
            sinks+=("$sink_name")
            sink_descs+=("$desc")
        done < <(pactl list short sinks)

        if [[ ${#sinks[@]} -eq 0 ]]; then
            echo "No valid output sink found to switch to." >&2
            exit 1
        fi

        default_sink=$(pactl info | grep 'Default Sink:' | awk -F': ' '{print $2}')
        # Find current default index in allowed list (may be -1 if current is unwanted)
        idx=-1
        for i in "${!sinks[@]}"; do
            if [[ "${sinks[$i]}" == "$default_sink" ]]; then
                idx=$i
                break
            fi
        done
        # Choose next index (wrap), if current not found then start from 0
        if [[ $idx -lt 0 ]]; then
            next_idx=0
        else
            next_idx=$(( (idx + 1) % ${#sinks[@]} ))
        fi

        # Safety loop: ensure we never land on the unwanted sink
        tried=0
        while [[ $tried -lt ${#sinks[@]} ]]; do
            next_sink="${sinks[$next_idx]}"
            desc="${sink_descs[$next_idx]}"
            if [[ "$next_sink" == "$UNWANTED_SINK_NAME" ]] || [[ "$desc" == "$UNWANTED_SINK_DESC" ]]; then
                next_idx=$(( (next_idx + 1) % ${#sinks[@]} ))
                tried=$((tried + 1))
                continue
            fi
            pactl set-default-sink "$next_sink"
            # Verify after switching by reading back default name
            new_default=$(pactl info | grep 'Default Sink:' | awk -F': ' '{print $2}')
            if [[ "$new_default" == "$UNWANTED_SINK_NAME" ]]; then
                next_idx=$(( (next_idx + 1) % ${#sinks[@]} ))
                tried=$((tried + 1))
                continue
            fi
            [[ -z "$desc" ]] && desc="$next_sink"
            if command -v notify-send &>/dev/null; then
                notify-send "Audio Output Switched" "$desc"
            else
                echo "$desc"
            fi
            exit 0
        done
        echo "No valid output sink found to switch to." >&2
        exit 1
    else
        echo "--toggle-output is only supported for PipeWire or PulseAudio." >&2
        exit 1
    fi
fi

# Check for gum
if ! command -v gum &>/dev/null; then
    echo "gum is required for this script. Please install gum."
    exit 1
fi



clear
choice=$(printf "🔈 Output (Speakers/Headset)\n🎤 Microphone (Input)\n🛠️ Switch Card Profile" | gum choose --header="Select device type to manage:")

case "$audio_system" in
    pipewire)
        if [[ "$choice" == "🎤 Microphone (Input)" ]]; then
            clear
            # ...original input device code...
            echo "🎤 Available audio input devices:"
            sources=()
            in_sources=0
            while IFS= read -r line; do
                if [[ $line =~ ^[[:space:]]*├─[[:space:]]Sources: ]]; then
                    in_sources=1
                    continue
                fi
                if [[ $in_sources -eq 1 ]]; then
                    if [[ $line =~ ^[[:space:]]*│ ]]; then
                        sources+=("$line")
                    else
                        break
                    fi
                fi
            done < <(wpctl status)
            if [ ${#sources[@]} -eq 0 ]; then
                echo "No audio input devices found."
                exit 1
            fi
            for i in "${!sources[@]}"; do
                line="${sources[$i]}"
                current=""
                if [[ $line == *'*'* ]]; then
                    current="[CURRENT] "
                fi
                id=$(echo "$line" | grep -oE '[0-9]+\. ' | head -1 | tr -d '.')
                name=$(echo "$line" | sed -E 's/^.*[0-9]+\. //')
                printf "🎤 %2d. %s%s (ID: %s)\n" $((i+1)) "$current" "$name" "$id"
            done
            read -p "Enter the number of the input device to set as default: " num
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#sources[@]} ]; then
                device_id=$(echo "${sources[$((num-1))]}" | grep -oE '[0-9]+\. ' | head -1 | tr -d '.')
                wpctl set-default $device_id
                echo "Set default input to $device_id."
            else
                echo "Invalid selection."
            fi
        elif [[ "$choice" == "🔈 Output (Speakers/Headset)" ]]; then
            clear
            # ...original output device code...
            echo "🔈 Available audio output devices:"
            mapfile -t sinks < <(pactl list sinks | grep -E 'Name:|Description:|Sink #' | sed 's/^\s*//')
            # Get the current default sink name
            default_sink=$(pactl info | grep 'Default Sink:' | awk -F': ' '{print $2}')
            count=0
            for ((i=0; i<${#sinks[@]}; i++)); do
                if [[ ${sinks[$i]} =~ ^Sink\ \# ]]; then
                    name="${sinks[$((i+1))]#Name: }"
                    desc="${sinks[$((i+2))]#Description: }"
                    # Only skip if description matches unwanted Family 17h/19h/1ah device
                    if [[ "$desc" == "Family 17h/19h/1ah HD Audio Controller Digital Stereo (IEC958)" ]]; then
                        continue
                    fi
                    count=$((count+1))
                    current=""
                    if [[ "$name" == "$default_sink" ]]; then
                        current="[CURRENT] "
                    fi
                    printf "🔊 %2d. %s%s (%s)\n" "$count" "$current" "$desc" "$name"
                fi
            done
            read -p "Enter the number of the output device to set as default: " num
            count=0
            selected_name=""
            for ((i=0; i<${#sinks[@]}; i++)); do
                if [[ ${sinks[$i]} =~ ^Sink\ \# ]]; then
                    name="${sinks[$((i+1))]#Name: }"
                    desc="${sinks[$((i+2))]#Description: }"
                    if [[ "$desc" == "Family 17h/19h/1ah HD Audio Controller Digital Stereo (IEC958)" ]]; then
                        continue
                    fi
                    count=$((count+1))
                    if [[ $count -eq $num ]]; then
                        selected_name="$name"
                        break
                    fi
                fi
            done
            if [ -n "$selected_name" ]; then
                pactl set-default-sink "$selected_name"
                echo "Set default output to $selected_name."
            else
                echo "Invalid selection."
            fi
        elif [[ "$choice" == "🛠️ Switch Card Profile" ]]; then
            clear
            echo "Available audio cards:"
            mapfile -t cards < <(pactl list short cards)
            for i in "${!cards[@]}"; do
                card_name=$(echo "${cards[$i]}" | awk '{print $2}')
                card_desc=$(pactl list cards | grep -A10 "Name: $card_name" | grep 'device.description' | head -1 | cut -d'=' -f2 | tr -d '" ')
                printf "%2d. %s (%s)\n" $((i+1)) "$card_name" "$card_desc"
            done
            read -p "Enter the number of the card to manage: " cardnum
            card_name=$(echo "${cards[$((cardnum-1))]}" | awk '{print $2}')
            echo "Available profiles for $card_name:"
            profiles=()
            while IFS= read -r line; do
                [[ $line =~ ^\s*([a-zA-Z0-9:_\-\+]+): ]] && profiles+=("${BASH_REMATCH[1]}")
            done < <(pactl list cards | awk "/Name: $card_name/{flag=1;next}/^Card #/{flag=0}flag" | grep -A20 'Profiles:' | grep -v 'Profiles:' | grep -v 'Active Profile:')
            for i in "${!profiles[@]}"; do
                printf "%2d. %s\n" $((i+1)) "${profiles[$i]}"
            done
            read -p "Enter the number of the profile to activate: " profnum
            profile_name="${profiles[$((profnum-1))]}"
            pactl set-card-profile "$card_name" "$profile_name"
            echo "Set $card_name to profile $profile_name."
        fi
        ;;
    pulseaudio)
        if [[ "$choice" == "🎤 Microphone (Input)" ]]; then
            clear
            echo "🎤 Available audio input devices:"
            pactl list short sources | nl -w2 -s'. '
            read -p "Enter the number of the input device to set as default: " num
            device_name=$(pactl list short sources | awk '{print $2}' | sed -n "${num}p")
            if [ -n "$device_name" ]; then
                pactl set-default-source "$device_name"
                echo "Set default input to $device_name."
            else
                echo "Invalid selection."
            fi
        elif [[ "$choice" == "🔈 Output (Speakers/Headset)" ]]; then
            clear
            echo "🔈 DEBUG: Raw output from 'pactl list sinks':"
            pactl list sinks
            echo "\n🔈 Available audio output devices:"
            # Show all sinks with index, name, and description for HDMI/DP visibility
            mapfile -t sinks < <(pactl list sinks | grep -E 'Name:|Description:|Sink #' | sed 's/^\s*//')
            count=0
            for ((i=0; i<${#sinks[@]}; i++)); do
                if [[ ${sinks[$i]} =~ ^Sink\ \# ]]; then
                    count=$((count+1))
                    name="${sinks[$((i+1))]#Name: }"
                    desc="${sinks[$((i+2))]#Description: }"
                    printf "🔊 %2d. %s (%s)\n" "$count" "$desc" "$name"
                fi
            done
            read -p "Enter the number of the output device to set as default: " num
            # Find the selected sink name
            count=0
            selected_name=""
            for ((i=0; i<${#sinks[@]}; i++)); do
                if [[ ${sinks[$i]} =~ ^Sink\ \# ]]; then
                    count=$((count+1))
                    if [[ $count -eq $num ]]; then
                        selected_name="${sinks[$((i+1))]#Name: }"
                        break
                    fi
                fi
            done
            if [ -n "$selected_name" ]; then
                pactl set-default-sink "$selected_name"
                echo "Set default output to $selected_name."
            else
                echo "Invalid selection."
            fi
        fi
        ;;
    alsa)
        if [[ "$choice" == "🎤 Microphone (Input)" ]]; then
            clear
            echo "ALSA does not support switching default input easily via script. Use 'alsamixer' or edit asoundrc."
        elif [[ "$choice" == "🔈 Output (Speakers/Headset)" ]]; then
            clear
            echo "🔈 Available audio output devices (ALSA):"
            aplay -l | grep '^card' || echo "No output devices found."
            echo "Switching default output is not easily scriptable in ALSA. Use 'alsamixer' or edit asoundrc."
        fi
        ;;
esac
