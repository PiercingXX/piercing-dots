#!/bin/sh

pkill -x sxhkd >/dev/null 2>&1 || true
sxhkd -c "$HOME/.config/sxhkd/sxhkdrc" &

pkill -x picom >/dev/null 2>&1 || true
picom -b --experimental-backends &

pkill -x nm-applet >/dev/null 2>&1 || true
nm-applet &

xrdb "$HOME/.Xresources" &
xsetroot -cursor_name left_ptr &
setxkbmap -layout us -variant colemak -option caps:backspace 2>/dev/null

if command -v feh >/dev/null 2>&1; then
	feh --bg-scale --no-fehbg "$HOME/.config/wall.png" &
fi

if command -v gnome-keyring-daemon >/dev/null 2>&1; then
	gnome-keyring-daemon --start --components=secrets >/dev/null 2>&1
fi

if [ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]; then
	/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
fi

# Status notifications (single-instance daemons; safe on reload)
for d in battery-notify.sh network-notify.sh bluetooth-notify.sh; do
	bash "$HOME/.scripts/Control-Scripts/$d" >/dev/null 2>&1 &
done
bash "$HOME/.scripts/Control-Scripts/wm-clipboard-daemon.sh" >/dev/null 2>&1 &
