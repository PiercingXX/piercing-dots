#!/bin/bash
# GitHub.com/PiercingXX
# Hardware Info: quick read-only views of the machine, plus disk usage.

SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck source=../lib/common.sh
. "$SCRIPT_DIR/../lib/common.sh"

command_exists gum || die "gum is required for this menu."

pager() { gum pager; }

battery_info() {
    if command_exists upower; then
        local dev
        for dev in $(upower -e | grep -E 'battery|BAT'); do
            upower -i "$dev"
        done
    else
        for b in /sys/class/power_supply/BAT*; do
            [ -d "$b" ] && echo "$(basename "$b"): $(cat "$b/capacity")% $(cat "$b/status")"
        done
    fi
}

disk_usage() {
    local path
    path=$(gum input --placeholder "folder to analyze" --value "$HOME") || return 0
    path="${path/#\~/$HOME}"
    [ -d "$path" ] || { err "No such folder: $path"; pause; return; }
    if command_exists dust; then
        dust -d 2 "$path" 2>/dev/null | pager
    elif command_exists ncdu; then
        ncdu "$path"
    else
        du -h --max-depth=1 "$path" 2>/dev/null | sort -rh | head -n 40 | pager
    fi
}

options=("Summary")
command_exists lscpu && options+=("CPU")
options+=("Memory" "Disks & partitions")
command_exists lspci && options+=("PCI devices & drivers")
command_exists lsusb && options+=("USB devices")
command_exists sensors && options+=("Temperatures")
ls /sys/class/power_supply/BAT* >/dev/null 2>&1 && options+=("Battery")
options+=("Disk usage of a folder" "Back")

while true; do
    clear
    choice=$(printf '%s\n' "${options[@]}" | gum choose --header "Hardware Info") || exit 0
    case "$choice" in
        "Summary")
            if command_exists fastfetch; then
                fastfetch --pipe 2>/dev/null | pager
            else
                { uname -a; echo; cat /etc/os-release 2>/dev/null; } | pager
            fi ;;
        "CPU")                    lscpu | pager ;;
        "Memory")                 { free -h; echo; swapon --show 2>/dev/null; } | pager ;;
        "Disks & partitions")     { lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS; echo; df -h -x tmpfs -x devtmpfs -x efivarfs; } | pager ;;
        "PCI devices & drivers")  lspci -k | pager ;;
        "USB devices")            lsusb | pager ;;
        "Temperatures")           sensors | pager ;;
        "Battery")                battery_info | pager ;;
        "Disk usage of a folder") disk_usage ;;
        *) exit 0 ;;
    esac
done
