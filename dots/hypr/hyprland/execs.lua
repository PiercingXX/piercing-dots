hl.on("hyprland.start", function()
    hl.exec_cmd([[~/.config/hypr/hyprland/scripts/SynoDrive.sh]])
    hl.exec_cmd([[bash -lc '[ -x ~/.scripts/Control-Scripts/hyprsunset-scheduler.sh ] && ~/.scripts/Control-Scripts/hyprsunset-scheduler.sh']])

    hl.exec_cmd([[bash -lc '[ -x ~/.local/bin/hyprpaper ] && exec ~/.local/bin/hyprpaper || exec hyprpaper']])
    hl.exec_cmd([[bash ~/.scripts/Control-Scripts/toggle-topbar.sh --startup]])
    hl.exec_cmd([[bash -lc 'command -v nm-applet >/dev/null && nm-applet']])
    hl.exec_cmd([[bash ~/.scripts/Control-Scripts/skippy-desk.sh autostart]])
    hl.exec_cmd([[xdg-user-dirs-update]])

    hl.exec_cmd([[bash -lc '
if command -v swaync >/dev/null 2>&1; then
    pgrep -x swaync >/dev/null || swaync
elif command -v notification-daemon >/dev/null 2>&1; then
    pgrep -x notification-daemon >/dev/null || notification-daemon
elif command -v dunst >/dev/null 2>&1; then
    pgrep -x dunst >/dev/null || dunst
fi']])

    hl.exec_cmd([[bash ~/.scripts/Control-Scripts/battery-notify.sh]])
    hl.exec_cmd([[bash ~/.scripts/Control-Scripts/workspace-notify.sh]])
    hl.exec_cmd([[bash ~/.scripts/Control-Scripts/network-notify.sh]])
    hl.exec_cmd([[bash ~/.scripts/Control-Scripts/bluetooth-notify.sh]])
    hl.exec_cmd([[bash -lc 'sleep 20 && ~/.scripts/Control-Scripts/update-notify.sh']])

    hl.exec_cmd([[gnome-keyring-daemon --start --components=secrets]])
    hl.exec_cmd([[bash -lc 'for p in \
    /usr/lib/polkit-kde-authentication-agent-1 \
    /usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1 \
    /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \
    /usr/libexec/polkit-gnome-authentication-agent-1 \
    /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1; do \
    [ -x "$p" ] && exec "$p"; \
done']])
    hl.exec_cmd([[hypridle]])
    hl.exec_cmd([[dbus-update-activation-environment --all]])
    hl.exec_cmd([[sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP]])
    hl.exec_cmd([[hyprpm reload]])

    hl.exec_cmd([=[bash -lc 'preferred=$(pactl list short sinks 2>/dev/null | awk "{print \$2}" | grep -i "SteelSeries_Arctis_Nova_Pro_Wireless" | head -n1); if [[ -n "$preferred" ]]; then pactl set-default-sink "$preferred"; wpctl set-default "$preferred" 2>/dev/null || true; pactl list short sink-inputs 2>/dev/null | awk "{print \$1}" | while read -r id; do pactl move-sink-input "$id" "$preferred" 2>/dev/null || true; done; else default_sink=$(pactl get-default-sink 2>/dev/null || true); if [[ "$default_sink" == *"iec958"* ]]; then candidate=$(pactl list short sinks 2>/dev/null | awk "{print \$2}" | grep -E "usb|hdmi|analog" | grep -v "iec958" | head -n1); [[ -n "$candidate" ]] && pactl set-default-sink "$candidate"; fi; fi']]=])
    hl.exec_cmd([[bash -lc 'command -v easyeffects >/dev/null && easyeffects --gapplication-service']])

    hl.exec_cmd([[bash ~/.scripts/Control-Scripts/wm-clipboard-daemon.sh]])
    hl.exec_cmd([[hyprctl setcursor Black-Minimalistic 22]])
    hl.exec_cmd([[bash -lc 'systemctl --user list-unit-files 2>/dev/null | grep -q "^docker-desktop.service" && systemctl --user start docker-desktop']])
end)
