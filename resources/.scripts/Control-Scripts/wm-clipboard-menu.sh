#!/bin/bash
# GitHub.com/PiercingXX
# Pick an entry from clipboard history and copy it back.
#   Wayland: cliphist + fuzzel   X11: history file from wm-clipboard-daemon.sh

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/piercingxx"
history_file="$cache_dir/clipboard-history.txt"

if is_wayland && command_exists cliphist && command_exists fuzzel && command_exists wl-copy; then
    # Toggle: a second press closes the open picker
    pkill -x fuzzel >/dev/null 2>&1 && exit 0
    selection="$(cliphist list | fuzzel --match-mode fzf --dmenu)" || exit 0
    [ -n "$selection" ] || exit 0
    printf '%s' "$selection" | cliphist decode | wl-copy
    exit 0
fi

[ -f "$history_file" ] || exit 0

selection="$(menu_select Clipboard < "$history_file")" || exit 0
[ -n "$selection" ] || exit 0

printf '%s' "$selection" | clip_copy
