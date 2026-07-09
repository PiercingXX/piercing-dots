#!/bin/bash

set -e

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/piercingxx"
history_file="$cache_dir/clipboard-history.txt"
pid_file="$cache_dir/clipboard-history.pid"

mkdir -p "$cache_dir"

if [ -f "$pid_file" ]; then
    existing_pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [ -n "$existing_pid" ] && kill -0 "$existing_pid" 2>/dev/null; then
        exit 0
    fi
fi

echo $$ > "$pid_file"
trap 'rm -f "$pid_file"' EXIT

append_entry() {
    local raw_text="$1"
    local entry
    entry="$(printf '%s' "$raw_text" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"

    [ -n "$entry" ] || return 0

    local tmp_file
    tmp_file="$(mktemp)"
    {
        printf '%s\n' "$entry"
        [ -f "$history_file" ] && grep -Fvx "$entry" "$history_file" || true
    } | head -n 200 > "$tmp_file"
    mv "$tmp_file" "$history_file"
}

if [ -n "$WAYLAND_DISPLAY" ] && command -v wl-paste >/dev/null 2>&1 && command -v cliphist >/dev/null 2>&1; then
    wl-paste --watch cliphist store &
    wl-paste --type text --watch cliphist store &
    wl-paste --type image --watch cliphist store &
    wait
    exit 0
fi

if ! command -v xclip >/dev/null 2>&1; then
    exit 0
fi

last_value=""
while true; do
    current_value="$(xclip -selection clipboard -o 2>/dev/null || true)"
    if [ -n "$current_value" ] && [ "$current_value" != "$last_value" ]; then
        append_entry "$current_value"
        last_value="$current_value"
    fi
    sleep 1
done