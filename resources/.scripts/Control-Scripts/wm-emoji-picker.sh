#!/bin/bash
# GitHub.com/PiercingXX
# Emoji picker: fuzzel-emoji / rofimoji when installed, else a built-in list.

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

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

if is_wayland && command_exists fuzzel-emoji; then
    exec fuzzel-emoji
fi

if command_exists rofimoji; then
    exec rofimoji
fi

emoji_list="$(load_emoji_list)"

choice="$(printf '%s\n' "$emoji_list" | menu_select Emoji)" || exit 0

emoji="${choice%% *}"
[ -n "$emoji" ] || exit 0

printf '%s' "$emoji" | clip_copy
