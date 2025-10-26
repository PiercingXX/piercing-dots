#!/bin/bash
# audio-input-manager.sh: Terminal UI to change audio input device (microphone)
# Auto-detects PipeWire, PulseAudio, or ALSA

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

# Gum menu for device type with emojis
choice=$(printf "🎤 Microphone (Input)\n🔈 Output (Speakers/Headset)" | gum choose --header="Select device type to manage:")

case "$audio_system" in
    pipewire)
    if [[ "$choice" == "🎤 Microphone (Input)" ]]; then
            echo "🎤 Available audio input devices:"
            # Extract the 'Sources:' block under 'Audio' using grep and awk
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
            echo "🔈 Available audio output devices:"
            # Extract the 'Sinks:' block under 'Audio' using grep and awk
            sinks=()
            in_sinks=0
            while IFS= read -r line; do
                if [[ $line =~ ^[[:space:]]*├─[[:space:]]Sinks: ]]; then
                    in_sinks=1
                    continue
                fi
                if [[ $in_sinks -eq 1 ]]; then
                    if [[ $line =~ ^[[:space:]]*│ ]]; then
                        sinks+=("$line")
                    else
                        break
                    fi
                fi
            done < <(wpctl status)
            if [ ${#sinks[@]} -eq 0 ]; then
                echo "No audio output devices found."
                exit 1
            fi
            for i in "${!sinks[@]}"; do
                line="${sinks[$i]}"
                current=""
                if [[ $line == *'*'* ]]; then
                    current="[CURRENT] "
                fi
                id=$(echo "$line" | grep -oE '[0-9]+\. ' | head -1 | tr -d '.')
                name=$(echo "$line" | sed -E 's/^.*[0-9]+\. //')
                printf "🔊 %2d. %s%s (ID: %s)\n" $((i+1)) "$current" "$name" "$id"
            done
            read -p "Enter the number of the output device to set as default: " num
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#sinks[@]} ]; then
                device_id=$(echo "${sinks[$((num-1))]}" | grep -oE '[0-9]+\. ' | head -1 | tr -d '.')
                wpctl set-default $device_id
                echo "Set default output to $device_id."
            else
                echo "Invalid selection."
            fi
        fi
        ;;
    pulseaudio)
        echo "Available audio input devices:" 
        pactl list short sources | nl -w2 -s'. '
        read -p "Enter the number of the input device to set as default: " num
        device_name=$(pactl list short sources | awk '{print $2}' | sed -n "${num}p")
        if [ -n "$device_name" ]; then
            pactl set-default-source $device_name
            echo "Set default input to $device_name."
        else
            echo "Invalid selection."
        fi
        ;;
    alsa)
        echo "ALSA does not support switching default input easily via script. Use 'alsamixer' or edit asoundrc."
        ;;
esac
