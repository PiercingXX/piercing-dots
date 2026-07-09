#!/bin/sh

export XDG_CURRENT_DESKTOP=dwm
export XDG_SESSION_DESKTOP=dwm

if [ -x "$HOME/.config/dwm/autostart.sh" ]; then
	"$HOME/.config/dwm/autostart.sh"
fi

exec dwm