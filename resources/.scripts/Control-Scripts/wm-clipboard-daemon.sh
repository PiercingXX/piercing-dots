#!/bin/bash
# GitHub.com/PiercingXX
# Clipboard history daemon.
#   Wayland: cliphist (one watcher for text, one for images)
#   X11:     plain-text history file, event-driven with clipnotify when
#            available, 1s polling otherwise.

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/piercingxx"
history_file="$cache_dir/clipboard-history.txt"

mkdir -p "$cache_dir"

single_instance clipboard-daemon || exit 0

append_entry() {
    local raw_text="$1"
    local entry
    entry="$(printf '%s' "$raw_text" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"

    [ -n "$entry" ] || return 0

    local tmp_file
    tmp_file="$(mktemp)"
    {
        printf '%s\n' "$entry"
        [ -f "$history_file" ] && grep -Fvx -- "$entry" "$history_file" || true
    } | head -n 200 > "$tmp_file"
    mv "$tmp_file" "$history_file"
}

if is_wayland && command_exists wl-paste && command_exists cliphist; then
    # Untyped + typed watchers would store every copy two or three times
    wl-paste --type text --watch cliphist store &
    wl-paste --type image --watch cliphist store &
    trap 'kill $(jobs -p) 2>/dev/null' EXIT INT TERM
    wait
    exit 0
fi

command_exists xclip || exit 0

last_value=""
check_clip() {
    local current_value
    current_value="$(xclip -selection clipboard -o 2>/dev/null || true)"
    if [ -n "$current_value" ] && [ "$current_value" != "$last_value" ]; then
        append_entry "$current_value"
        last_value="$current_value"
    fi
}

if command_exists clipnotify; then
    # clipnotify blocks until the selection changes
    while clipnotify -s clipboard; do
        check_clip
    done
else
    while true; do
        check_clip
        sleep 1
    done
fi
