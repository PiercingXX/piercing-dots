#!/bin/bash
# GitHub.com/PiercingXX
# PiercingXX Settings Menu. Every entry is a script next to this file.

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"
detect_distro

# Child scripts can tell they were launched from here (and skip their own
# trailing "press Enter" when this menu already pauses for them).
export PIERCINGXX_FROM_MENU=1

# gum drives every submenu; install it if we can, otherwise fall back to select
if ! command_exists gum; then
    say "gum not found. Installing..."
    pkg_install gum || warn "Could not install gum automatically (on Debian, see https://github.com/charmbracelet/gum#installation)."
fi

use_ascii_menu=0
if [[ ${PIERCINGXX_ASCII_MENU:-0} == 1 ]] || [[ -t 1 && ${TERM:-} == "linux" ]]; then
    use_ascii_menu=1
fi
export PIERCINGXX_ASCII_MENU="$use_ascii_menu"

# One table: icon | label | script | flags
#   flags: pause = wait for Enter after the script returns
#          arch  = only on Arch-based systems (reflector/pacman mirrors)
MENU_TABLE=(
    "🚀|Update System|update-system.sh|pause"
    "📦|Software Manager|terminal-software-manager.sh|"
    "🎤|Audio Devices|audio-input-manager.sh|"
    "📶|WiFi Manager|wifi-manager.sh|"
    "🔵|Bluetooth Manager|bluetooth-manager.sh|"
    "🖼️|Change Wallpaper|change-wallpaper.sh|pause"
    "⌨️|Keyboard Layout|keyboard-layout.sh|"
    "🔋|Power & Night Light|power-manager.sh|"
    "🧱|Firewall|firewall-manager.sh|"
    "⚙️|Services|service-manager.sh|"
    "📜|Logs|log-viewer.sh|"
    "🖥️|Hardware Info|hardware-info.sh|"
    "🗄️|Backup & Restore|backup-restore.sh|"
    "👤|User Management|user-management.sh|"
    "✨|Update PiercingXX Rice|update-piercingXX.sh|pause"
    "🌐|Update Mirrors|update-mirrors.sh|pause,arch"
    "🛡️|Virus Scan|virus-scan.sh|"
    "🧹|Clean System|clean-system.sh|pause"
)

options=()
scripts=()
flags=()
for row in "${MENU_TABLE[@]}"; do
    IFS='|' read -r icon label script flag <<< "$row"
    if [[ ",$flag," == *",arch,"* ]] && [ "$DISTRO" != arch ]; then
        continue
    fi
    [ -f "$SCRIPT_DIR/$script" ] || continue
    if [[ $use_ascii_menu -eq 1 ]]; then
        options+=("> $label")
    else
        options+=("$icon $label")
    fi
    scripts+=("$script")
    flags+=("$flag")
done
if [[ $use_ascii_menu -eq 1 ]]; then
    quit_label="> Quit"
else
    quit_label="🚪 Quit"
fi
options+=("$quit_label")

pick() {
    if command_exists gum; then
        printf "%s\n" "${options[@]}" | gum filter --header="$1" --placeholder="Search or select an option..."
    else
        local PS3="Choose: " opt
        select opt in "${options[@]}"; do
            [ -n "$opt" ] && { echo "$opt"; return 0; }
        done
        return 1
    fi
}

header="PiercingXX - Settings Menu (type to search)"
esc_count=0
while true; do
    clear
    selected=$(pick "$header")
    rc=$?
    # Ctrl-C quits; Esc twice in a row quits; one stray Esc just redraws
    if [ $rc -eq 130 ]; then
        clear
        exit 0
    fi
    if [ -z "$selected" ]; then
        esc_count=$((esc_count + 1))
        if [ $esc_count -ge 2 ]; then
            clear
            exit 0
        fi
        header="PiercingXX - Settings Menu (Esc again to quit)"
        continue
    fi
    esc_count=0
    header="PiercingXX - Settings Menu (type to search)"

    if [ "$selected" = "$quit_label" ]; then
        clear
        exit 0
    fi

    for i in "${!options[@]}"; do
        [ "${options[$i]}" = "$selected" ] || continue
        clear
        if [[ ",${flags[$i]}," == *",pause,"* ]]; then
            # This menu pauses afterwards, so the script skips its own final pause
            PX_NO_PAUSE=1 bash "$SCRIPT_DIR/${scripts[$i]}"
        else
            bash "$SCRIPT_DIR/${scripts[$i]}"
        fi
        status=$?
        if [ $status -ne 0 ] && [ $status -ne 130 ]; then
            echo
            warn "${scripts[$i]} exited with code $status."
            pause
        elif [[ ",${flags[$i]}," == *",pause,"* ]]; then
            echo
            pause "Press Enter to return to the menu..."
        fi
        break
    done
done
