#!/bin/bash
# GitHub.com/PiercingXX
# Audio Input/Output Manager for PipeWire (WirePlumber).
#   audio-input-manager.sh                 interactive menu
#   audio-input-manager.sh --toggle-output cycle the default output (keybind)
#
# Devices are read from `pw-dump` (stable JSON) instead of parsing `wpctl status`.
# Outputs whose description matches PIERCINGXX_AUDIO_SKIP (extended regex) are
# hidden; the default hides S/PDIF "Digital Stereo (IEC958)" outputs. Set
# PIERCINGXX_AUDIO_SKIP="" to show everything.

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

AUDIO_SKIP="${PIERCINGXX_AUDIO_SKIP-IEC958}"

notify_error() {
    if command_exists notify-send; then
        notify-send -u normal -a Audio "Audio" "$1"
    fi
    echo "$1" >&2
}

play_switch_chime() {
    local f
    for f in /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga /usr/share/sounds/alsa/Front_Center.wav; do
        [ -f "$f" ] || continue
        if command_exists pw-play; then
            pw-play "$f" >/dev/null 2>&1 &
        elif command_exists paplay; then
            paplay "$f" >/dev/null 2>&1 &
        fi
        return
    done
}

command_exists wpctl || { notify_error "wpctl not found. This script requires PipeWire + WirePlumber."; exit 1; }
command_exists pw-dump || { notify_error "pw-dump not found (part of pipewire)."; exit 1; }
command_exists jq || { notify_error "jq not found."; exit 1; }
wpctl status >/dev/null 2>&1 || { notify_error "PipeWire is not running or not reachable in this session."; exit 1; }

# list_nodes Audio/Sink|Audio/Source -> "id<TAB>description" lines
list_nodes() {
    local class="$1"
    pw-dump 2>/dev/null | jq -r --arg c "$class" '
        .[] | select(.type == "PipeWire:Interface:Node")
            | select(.info.props["media.class"] == $c)
            | select((.info.props["node.virtual"] // false) != true)
            | select(.info.props["node.link-group"] == null)
            | "\(.id)\t\(.info.props["node.description"] // .info.props["node.nick"] // .info.props["node.name"])"' \
    | { if [ -n "$AUDIO_SKIP" ] && [ "$class" = "Audio/Sink" ]; then grep -Ev "$AUDIO_SKIP"; else cat; fi; }
}

# default_id @DEFAULT_AUDIO_SINK@|@DEFAULT_AUDIO_SOURCE@
default_id() {
    wpctl inspect "$1" 2>/dev/null | head -n 1 | grep -oE 'id [0-9]+' | grep -oE '[0-9]+'
}

# Older WirePlumber (< 0.5, e.g. Debian stable) doesn't always move running
# streams when the default changes; nudge them over with pactl if it exists.
move_streams() {
    local id="$1" node_name
    command_exists pactl || return 0
    node_name=$(pw-dump 2>/dev/null | jq -r --argjson i "$id" '.[] | select(.id == $i) | .info.props["node.name"] // empty')
    [ -n "$node_name" ] || return 0
    pactl list short sink-inputs 2>/dev/null | awk '{print $1}' | while read -r stream_id; do
        pactl move-sink-input "$stream_id" "$node_name" 2>/dev/null || true
    done
}

# ---------------------------------------------------------------------------
# Keybind mode: cycle outputs
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--toggle-output" ]]; then
    mapfile -t sinks < <(list_nodes "Audio/Sink")
    [ ${#sinks[@]} -gt 0 ] || { notify_error "No audio output devices found."; exit 1; }

    current=$(default_id @DEFAULT_AUDIO_SINK@)
    next_idx=0
    for i in "${!sinks[@]}"; do
        if [ "${sinks[$i]%%$'\t'*}" = "$current" ]; then
            next_idx=$(( (i + 1) % ${#sinks[@]} ))
            break
        fi
    done
    next_id="${sinks[$next_idx]%%$'\t'*}"
    next_name="${sinks[$next_idx]#*$'\t'}"

    wpctl set-default "$next_id" || { notify_error "Could not switch to $next_name."; exit 1; }
    move_streams "$next_id"
    if command_exists notify-send; then
        notify_replace audio-output low 2000 audio-speakers "Audio Output Switched" "$next_name"
    else
        echo "Switched to: $next_name"
    fi
    play_switch_chime
    exit 0
fi

# ---------------------------------------------------------------------------
# Interactive menu
# ---------------------------------------------------------------------------
command_exists gum || { echo "gum is required for interactive mode (or use --toggle-output)." >&2; exit 1; }

if [[ "${PIERCINGXX_ASCII_MENU:-0}" == 1 ]]; then
    out_label="Output (Speakers/Headset)"; in_label="Microphone (Input)"
else
    out_label="🔈 Output (Speakers/Headset)"; in_label="🎤 Microphone (Input)"
fi

# choose_device CLASS DEFAULT_ALIAS KIND
choose_device() {
    local class="$1" alias="$2" kind="$3" current line id name pick
    local -a nodes labels
    mapfile -t nodes < <(list_nodes "$class")
    [ ${#nodes[@]} -gt 0 ] || { err "No audio $kind devices found."; return 1; }
    current=$(default_id "$alias")

    for line in "${nodes[@]}"; do
        id="${line%%$'\t'*}"; name="${line#*$'\t'}"
        if [ "$id" = "$current" ]; then
            labels+=("$name  [current]  #$id")
        else
            labels+=("$name  #$id")
        fi
    done

    pick=$(printf '%s\n' "${labels[@]}" | gum choose --header "Set default $kind device") || return 0
    [ -n "$pick" ] || return 0
    id="${pick##*#}"
    if wpctl set-default "$id"; then
        [ "$class" = "Audio/Sink" ] && move_streams "$id"
        ok "Default $kind set to: ${pick%%  *}"
    else
        err "Could not set default $kind."
        return 1
    fi
}

while true; do
    clear
    choice=$(printf '%s\n' "$out_label" "$in_label" "Back" | gum choose --header="Select device type to manage:")
    case "$choice" in
        "$out_label") choose_device "Audio/Sink" @DEFAULT_AUDIO_SINK@ output ;;
        "$in_label")  choose_device "Audio/Source" @DEFAULT_AUDIO_SOURCE@ input ;;
        *) exit 0 ;;
    esac
    pause
done
