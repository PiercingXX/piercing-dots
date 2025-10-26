#!/bin/bash
# GitHub.com/PiercingXX

set -e

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

# Check for gum
if ! command -v gum &>/dev/null; then
    echo "gum is required for this script. Please install gum."
    exit 1
fi


choice=$(printf "🔈 Output (Speakers/Headset)\n🎤 Microphone (Input)\n🛠️ Switch Card Profile" | gum choose --header="Select device type to manage:")

case "$audio_system" in
    pipewire)
        if [[ "$choice" == "🎤 Microphone (Input)" ]]; then
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
            # ...original output device code...
            echo "🔈 Available audio output devices:"
            mapfile -t sinks < <(pactl list sinks | grep -E 'Name:|Description:|Sink #' | sed 's/^\s*//')
            # Get the current default sink name
            default_sink=$(pactl info | grep 'Default Sink:' | awk -F': ' '{print $2}')
            count=0
            for ((i=0; i<${#sinks[@]}; i++)); do
                if [[ ${sinks[$i]} =~ ^Sink\ \# ]]; then
                    count=$((count+1))
                    name="${sinks[$((i+1))]#Name: }"
                    desc="${sinks[$((i+2))]#Description: }"
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
        elif [[ "$choice" == "🛠️ Switch Card Profile" ]]; then
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
            echo "ALSA does not support switching default input easily via script. Use 'alsamixer' or edit asoundrc."
        elif [[ "$choice" == "🔈 Output (Speakers/Headset)" ]]; then
            echo "🔈 Available audio output devices (ALSA):"
            aplay -l | grep '^card' || echo "No output devices found."
            echo "Switching default output is not easily scriptable in ALSA. Use 'alsamixer' or edit asoundrc."
        fi
        ;;
esac
