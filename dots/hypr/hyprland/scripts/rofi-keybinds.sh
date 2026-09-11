#!/bin/bash

HYPR_CONF="$HOME/.config/hypr/hyprland/keybinds.lua"
[ -f "$HYPR_CONF" ] || HYPR_CONF="$HOME/.config/hypr/hyprland/keybinds.conf"

if [ ! -f "$HYPR_CONF" ]; then
    notify-send "Hyprland keybinds" "No keybinds.lua/conf found" 2>/dev/null || true
    exit 1
fi

# Lua binds look like:  hl.bind({ "SUPER" }, "Q", [[killactive]])
# Legacy conf binds:    bind=SUPER,Q,killactive
if [[ "$HYPR_CONF" == *.lua ]]; then
    mapfile -t BINDINGS < <(
        grep -E '^\s*hl\.bind' "$HYPR_CONF" | \
        sed -E \
            -e 's/^\s*hl\.bind\(?\s*\{?\s*//' \
            -e 's/\}\s*,\s*/ + /' \
            -e 's/"([^"]+)"/\1/g' \
            -e "s/'([^']+)'/\1/g" \
            -e 's/\[\[([^\]]+)\]\]/\1/g' \
            -e 's/\)$//' \
            -e 's/,\s*/, /g' | \
        awk -F', ' '{
            mods=$1; key=$2; cmd="";
            for(i=3;i<=NF;i++){ if(cmd!="") cmd=cmd " "; cmd=cmd $i }
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", mods)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", cmd)
            printf "<b>%s + %s</b>  <i>%s</i>\n", mods, key, cmd
        }'
    )
else
    mapfile -t BINDINGS < <(grep '^bind=' "$HYPR_CONF" | \
        sed -e 's/  */ /g' -e 's/bind=//g' -e 's/, /,/g' -e 's/ # /,/' | \
        awk -F, -v q="'" '{cmd=""; for(i=3;i<NF;i++) cmd=cmd $(i) " ";print "<b>"$1 " + " $2 "</b>  <i>" $NF ",</i><span color=" q "gray" q ">" cmd "</span>"}')
fi

CHOICE=$(printf '%s\n' "${BINDINGS[@]}" | rofi -dmenu -i -markup-rows -p "Hyprland Keybinds:")
[ -z "$CHOICE" ] && exit 0

# Prefer gray-span cmd (legacy), else italic body (lua)
CMD=$(echo "$CHOICE" | sed -n 's/.*<span color='\''gray'\''>\(.*\)<\/span>.*/\1/p')
if [ -z "$CMD" ]; then
    CMD=$(echo "$CHOICE" | sed -n 's/.*<i>\(.*\)<\/i>.*/\1/p')
fi
CMD=$(echo "$CMD" | sed 's/[[:space:]]*$//')

if [[ $CMD == exec* ]]; then
    eval "$CMD"
elif [ -n "$CMD" ]; then
    hyprctl dispatch "$CMD"
fi
