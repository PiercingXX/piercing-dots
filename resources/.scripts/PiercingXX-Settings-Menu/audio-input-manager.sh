#!/bin/bash
# GitHub.com/PiercingXX
# Audio Input/Output Manager for PipeWire

set -e

# Detect if PipeWire is available
if ! command -v wpctl &>/dev/null; then
    echo "Error: wpctl not found. This script requires PipeWire." >&2
    exit 1
fi

# Handle --toggle-output flag for keybinds
if [[ "$1" == "--toggle-output" ]]; then
    # Get all sinks, filtering out the unwanted one
    mapfile -t sink_data < <(wpctl status | awk '/Audio/,/Video/' | awk '/Sinks:/,/Sources:/' | grep -E '^\s+│\s+.*[0-9]+\.')
    
    sinks=()
    current_idx=-1
    
    for line in "${sink_data[@]}"; do
        # Skip the unwanted Family 17h device
        if [[ "$line" =~ "Family 17h/19h/1ah HD Audio Controller Digital Stereo (IEC958)" ]]; then
            continue
        fi
        
        # Extract ID
        id=$(echo "$line" | grep -oE '[0-9]+\.' | head -1 | tr -d '.')
        
        if [[ -n "$id" ]]; then
            sinks+=("$id")
            # Check if this is the current default (has asterisk)
            if [[ "$line" =~ \*.*${id}\. ]]; then
                current_idx=$((${#sinks[@]} - 1))
            fi
        fi
    done
    
    if [[ ${#sinks[@]} -eq 0 ]]; then
        echo "No audio output devices found" >&2
        exit 1
    fi
    
    # Calculate next index
    if [[ $current_idx -eq -1 ]]; then
        next_idx=0
    else
        next_idx=$(( (current_idx + 1) % ${#sinks[@]} ))
    fi
    
    next_sink="${sinks[$next_idx]}"
    wpctl set-default "$next_sink"
    
    # Get the actual sink name (node.name) for pactl compatibility
    node_name=$(wpctl inspect "$next_sink" | grep 'node.name' | head -1 | sed 's/.*node.name = "\(.*\)".*/\1/')
    
    if [[ -n "$node_name" ]]; then
        # Move all existing playback streams to the new sink
        pactl list short sink-inputs | awk '{print $1}' | while read -r stream_id; do
            pactl move-sink-input "$stream_id" "$node_name" 2>/dev/null || true
        done
    fi
    
    # Get the human-readable name for notification
    sink_name_full=$(wpctl status | grep -E "^\s+│\s+\*?\s*${next_sink}\." | sed -E 's/.*[0-9]+\.\s+//' | sed 's/\s*\[vol:.*$//')
    
    if command -v notify-send &>/dev/null; then
        notify-send "Audio Output Switched" "$sink_name_full"
    else
        echo "Switched to: $sink_name_full"
    fi
    exit 0
fi

# Interactive menu mode
if ! command -v gum &>/dev/null; then
    echo "Error: gum is required for interactive mode. Install it or use --toggle-output flag." >&2
    exit 1
fi

clear

choice=$(printf "🔈 Output (Speakers/Headset)\n🎤 Microphone (Input)" | gum choose --header="Select device type to manage:")

if [[ "$choice" == "🎤 Microphone (Input)" ]]; then
    clear
    echo "🎤 Available audio input devices:"
    echo ""
    
    # Get sources from wpctl
    mapfile -t source_data < <(wpctl status | awk '/Audio/,/Video/' | awk '/Sources:/,/Filters:/' | grep -E '^\s+│\s+.*[0-9]+\.')
    
    source_ids=()
    source_names=()
    
    for line in "${source_data[@]}"; do
        id=$(echo "$line" | grep -oE '[0-9]+\.' | head -1 | tr -d '.')
        name=$(echo "$line" | sed -E 's/.*[0-9]+\.\s+//' | sed 's/\s*\[vol:.*$//')
        
        if [[ -n "$id" ]]; then
            source_ids+=("$id")
            source_names+=("$name")
        fi
    done
    
    if [[ ${#source_ids[@]} -eq 0 ]]; then
        echo "No audio input devices found."
        exit 1
    fi
    
    # Display sources
    for i in "${!source_ids[@]}"; do
        current=""
        # Check if this is the current default
        if wpctl status | grep -E "^\s+│\s+\*\s+${source_ids[$i]}\." &>/dev/null; then
            current="[CURRENT] "
        fi
        printf "  %2d. %s%s (ID: %s)\n" $((i+1)) "$current" "${source_names[$i]}" "${source_ids[$i]}"
    done
    
    echo ""
    read -p "Enter the number of the input device to set as default: " num
    
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#source_ids[@]} ]; then
        selected_id="${source_ids[$((num-1))]}"
        wpctl set-default "$selected_id"
        echo "✓ Set default input to: ${source_names[$((num-1))]}"
    else
        echo "✗ Invalid selection."
        exit 1
    fi
    
elif [[ "$choice" == "🔈 Output (Speakers/Headset)" ]]; then
    clear
    echo "🔈 Available audio output devices:"
    echo ""
    
    # Get sinks from wpctl
    mapfile -t sink_data < <(wpctl status | awk '/Audio/,/Video/' | awk '/Sinks:/,/Sources:/' | grep -E '^\s+│\s+.*[0-9]+\.')
    
    sink_ids=()
    sink_names=()
    
    for line in "${sink_data[@]}"; do
        # Skip the unwanted Family 17h device
        if [[ "$line" =~ "Family 17h/19h/1ah HD Audio Controller Digital Stereo (IEC958)" ]]; then
            continue
        fi
        
        id=$(echo "$line" | grep -oE '[0-9]+\.' | head -1 | tr -d '.')
        name=$(echo "$line" | sed -E 's/.*[0-9]+\.\s+//' | sed 's/\s*\[vol:.*$//')
        
        if [[ -n "$id" ]]; then
            sink_ids+=("$id")
            sink_names+=("$name")
        fi
    done
    
    if [[ ${#sink_ids[@]} -eq 0 ]]; then
        echo "No audio output devices found."
        exit 1
    fi
    
    # Display sinks
    for i in "${!sink_ids[@]}"; do
        current=""
        # Check if this is the current default
        if wpctl status | grep -E "^\s+│\s+\*\s+${sink_ids[$i]}\." &>/dev/null; then
            current="[CURRENT] "
        fi
        printf "  %2d. %s%s (ID: %s)\n" $((i+1)) "$current" "${sink_names[$i]}" "${sink_ids[$i]}"
    done
    
    echo ""
    read -p "Enter the number of the output device to set as default: " num
    
    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#sink_ids[@]} ]; then
        selected_id="${sink_ids[$((num-1))]}"
        wpctl set-default "$selected_id"
        echo "✓ Set default output to: ${sink_names[$((num-1))]}"
    else
        echo "✗ Invalid selection."
        exit 1
    fi
fi
