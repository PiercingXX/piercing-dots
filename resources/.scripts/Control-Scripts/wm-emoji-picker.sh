#!/bin/bash

set -e

load_emoji_list() {
    local emoji_file=""
    local candidates=(
        /usr/share/unicode/emoji/emoji-test.txt
        /usr/share/unicode/emoji-test.txt
        /usr/share/doc/unicode-emoji/emoji-test.txt
    )

    for candidate in "${candidates[@]}"; do
        if [ -r "$candidate" ]; then
            emoji_file="$candidate"
            break
        fi
    done

    if [ -n "$emoji_file" ]; then
        awk '
            /^[[:space:]]*#/ { next }
            /;[[:space:]]*fully-qualified[[:space:]]*#/ {
                split($0, parts, "# ")
                if (length(parts) < 2) next
                split(parts[2], right, " E[0-9.]+ ")
                emoji = right[1]
                desc = right[2]
                if (emoji != "" && desc != "") print emoji " " desc
            }
        ' "$emoji_file"
        return
    fi

    cat <<'EOF'
😀 Grinning Face
😂 Face with Tears of Joy
🙂 Slightly Smiling Face
😉 Winking Face
😍 Smiling Face with Heart-Eyes
🤔 Thinking Face
😭 Loudly Crying Face
😎 Smiling Face with Sunglasses
👍 Thumbs Up
👎 Thumbs Down
❤️ Red Heart
🔥 Fire
✨ Sparkles
🎉 Party Popper
✅ Check Mark
❌ Cross Mark
⚠️ Warning
🚀 Rocket
📌 Pushpin
📷 Camera
EOF
}

if [ -n "$WAYLAND_DISPLAY" ] && command -v fuzzel-emoji >/dev/null 2>&1; then
    exec fuzzel-emoji
fi

if command -v rofimoji >/dev/null 2>&1; then
    exec rofimoji
fi

emoji_list="$(load_emoji_list)"

if command -v rofi >/dev/null 2>&1; then
    choice="$(printf '%s\n' "$emoji_list" | rofi -dmenu -i -p Emoji)"
elif command -v fuzzel >/dev/null 2>&1; then
    choice="$(printf '%s\n' "$emoji_list" | fuzzel --dmenu)"
else
    exit 1
fi

emoji="${choice%% *}"
[ -n "$emoji" ] || exit 0

if command -v xclip >/dev/null 2>&1; then
    printf '%s' "$emoji" | xclip -selection clipboard
elif command -v wl-copy >/dev/null 2>&1; then
    printf '%s' "$emoji" | wl-copy
fi