"""Qtile config based on the PiercingXX Hyprland workflow."""

from __future__ import annotations

import os
import subprocess

from libqtile import bar, hook, layout, qtile, widget
from libqtile.backend.wayland import InputConfig
from libqtile.config import Click, Drag, Group, Key, Match, Screen
from libqtile.lazy import lazy

mod = "mod4"
terminal = "kitty"
browser = "bash -lc 'command -v waterfox >/dev/null 2>&1 && exec waterfox || exec flatpak run net.waterfox.waterfox'"
file_manager = "nautilus --new-window"
launcher = os.path.expanduser("~/.scripts/Control-Scripts/wm-app-launcher.sh")

keys = [
    Key([], "XF86Tools", lazy.spawn(launcher), desc="Launcher"),
    Key(["mod1"], "Tab", lazy.spawn(launcher), desc="Launcher"),
    Key([mod], "q", lazy.window.kill(), desc="Kill focused window"),
    Key([mod, "shift"], "f", lazy.window.toggle_fullscreen(), desc="Fullscreen"),
    Key([mod], "f", lazy.window.toggle_floating(), desc="Toggle floating"),
    Key([mod], "r", lazy.restart(), desc="Reload Qtile"),
    Key([], "Print", lazy.spawn("~/.scripts/Control-Scripts/wm-screenshot.sh region"), desc="Screenshot region"),
    Key(["shift"], "Print", lazy.spawn("~/.scripts/Control-Scripts/wm-screenshot.sh window"), desc="Screenshot window"),
    Key([mod, "control"], "h", lazy.spawn("bash ~/.scripts/Control-Scripts/wm-clipboard-menu.sh"), desc="Clipboard history"),
    Key([mod], "n", lazy.spawn("kitty ~/.scripts/Note-Scripts/open_daily_note.sh --split"), desc="Daily note split"),
    Key([mod, "shift"], "n", lazy.spawn("kitty ~/.scripts/Note-Scripts/open_daily_note.sh --view"), desc="Daily note view"),
    Key([mod, "mod1"], "n", lazy.spawn("kitty ~/.scripts/Note-Scripts/open_daily_note.sh --todo"), desc="Todo list"),
    Key([mod, "shift", "mod1"], "n", lazy.spawn("kitty ~/.scripts/Note-Scripts/open_daily_note.sh --directory"), desc="Notes directory"),
    Key([mod], "i", lazy.spawn("kitty ~/.scripts/Note-Scripts/inventory.sh"), desc="Inventory"),
    Key([mod], "m", lazy.spawn("kitty -o allow_remote_control=yes -o close_on_child_death=yes ~/.scripts/Control-Scripts/launch-server-monitor.sh -monitor"), desc="Server monitor"),
    Key([mod, "shift"], "m", lazy.spawn("kitty -o allow_remote_control=yes -o close_on_child_death=yes ~/.scripts/Control-Scripts/launch-server-monitor.sh -remote"), desc="Server remote"),
    Key([mod], "w", lazy.spawn("kitty"), desc="Terminal"),
    Key([mod], "t", lazy.spawn("kitty tmux"), desc="Tmux"),
    Key([mod, "shift"], "z", lazy.spawn(file_manager), desc="Nautilus"),
    Key([mod], "z", lazy.spawn("kitty yazi"), desc="Yazi"),
    Key([mod], "c", lazy.spawn(browser), desc="Browser"),
    Key([mod], "d", lazy.spawn("discord || flatpak run com.discordapp.Discord"), desc="Discord"),
    Key([mod, "shift"], "v", lazy.spawn("opencode-desktop"), desc="OpenCode desktop"),
    Key([mod], "v", lazy.spawn("kitty nvim"), desc="Neovim"),
    Key([mod, "mod1"], "v", lazy.spawn("code"), desc="VS Code"),
    Key([mod], "b", lazy.spawn("obsidian || flatpak run md.obsidian.Obsidian"), desc="Obsidian"),
    Key([mod], "g", lazy.spawn("gimp || flatpak run org.gimp.GIMP"), desc="GIMP"),
    Key(["control", "mod1"], "Delete", lazy.spawn("kitty flatpak run io.missioncenter.MissionCenter"), desc="Mission Center"),
    Key(["control", "mod1", "shift"], "k", lazy.spawn("sudo shutdown -h now"), desc="Shutdown"),
    Key([mod], "slash", lazy.spawn('xdg-open "$HOME/.scripts/Control-Scripts/keybinds.html"'), desc="Show keybinds"),
    Key([mod], "a", lazy.spawn("kitty ~/.scripts/Control-Scripts/launch-skippy-remote.sh"), desc="Skippy remote"),
    Key([mod, "shift"], "a", lazy.spawn("kitty ~/.scripts/Control-Scripts/launch-ollama-remote.sh --skippy"), desc="Ollama skippy"),
    Key([mod, "mod1"], "a", lazy.spawn("kitty ~/.scripts/Control-Scripts/launch-ollama-remote.sh --gemma"), desc="Ollama gemma"),
    Key([mod], "grave", lazy.spawn("hyprlock || betterlockscreen -l"), desc="Lock"),
    Key([mod, "shift"], "grave", lazy.spawn("sleep 0.1 && systemctl suspend || loginctl suspend"), desc="Suspend"),
    Key([mod, "control", "shift"], "Delete", lazy.spawn("systemctl poweroff || loginctl poweroff"), desc="Power off"),
    Key([mod], "h", lazy.layout.left(), desc="Focus left"),
    Key([mod], "j", lazy.layout.down(), desc="Focus down"),
    Key([mod], "k", lazy.layout.up(), desc="Focus up"),
    Key([mod], "l", lazy.layout.right(), desc="Focus right"),
    Key([mod, "shift"], "h", lazy.layout.shuffle_left(), desc="Move left"),
    Key([mod, "shift"], "j", lazy.layout.shuffle_down(), desc="Move down"),
    Key([mod, "shift"], "k", lazy.layout.shuffle_up(), desc="Move up"),
    Key([mod, "shift"], "l", lazy.layout.shuffle_right(), desc="Move right"),
    Key([mod, "mod1"], "h", lazy.layout.grow_left(), desc="Grow left"),
    Key([mod, "mod1"], "j", lazy.layout.grow_down(), desc="Grow down"),
    Key([mod, "mod1"], "k", lazy.layout.grow_up(), desc="Grow up"),
    Key([mod, "mod1"], "l", lazy.layout.grow_right(), desc="Grow right"),
    Key([mod], "x", lazy.next_layout(), desc="Next layout"),
    Key([mod, "shift"], "s", lazy.spawn("pavucontrol"), desc="Audio mixer"),
    Key([mod, "mod1"], "s", lazy.spawn('XDG_CURRENT_DESKTOP="gnome" gnome-control-center'), desc="GNOME settings"),
    Key([mod], "s", lazy.spawn("kitty ~/.scripts/PiercingXX-Settings-Menu/settings-menu.sh"), desc="Settings menu"),
    Key([mod], "o", lazy.spawn("bash -lc '~/.scripts/PiercingXX-Settings-Menu/audio-input-manager.sh --toggle-output'"), desc="Toggle audio output"),
    Key([mod], "p", lazy.spawn("bash -lc '~/.scripts/Control-Scripts/notify-time.sh'"), desc="Show time"),
    Key([mod, "shift"], "p", lazy.spawn("bash -lc '~/.scripts/Control-Scripts/notify-calendar.sh'"), desc="Show calendar"),
    Key([], "XF86AudioPlay", lazy.spawn("playerctl --all-players play-pause"), desc="Play pause"),
    Key([], "XF86AudioNext", lazy.spawn("playerctl next"), desc="Next track"),
    Key([], "XF86AudioPrev", lazy.spawn("playerctl previous"), desc="Previous track"),
    Key([], "XF86AudioRaiseVolume", lazy.spawn("~/.scripts/Control-Scripts/volume.sh inc"), desc="Volume up"),
    Key([], "XF86AudioLowerVolume", lazy.spawn("~/.scripts/Control-Scripts/volume.sh dec"), desc="Volume down"),
    Key([], "XF86AudioMute", lazy.spawn("~/.scripts/Control-Scripts/volume.sh mute"), desc="Mute"),
    Key([], "XF86AudioMicMute", lazy.spawn("pactl set-source-mute @DEFAULT_SOURCE@ toggle"), desc="Mic mute"),
    Key([], "XF86MonBrightnessDown", lazy.spawn("~/.scripts/Control-Scripts/brightness.sh dec"), desc="Brightness down"),
    Key([], "XF86MonBrightnessUp", lazy.spawn("~/.scripts/Control-Scripts/brightness.sh inc"), desc="Brightness up"),
]

group_names = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
groups = [Group(name) for name in group_names]

for i, group in enumerate(groups, 1):
    key_name = "0" if i == 10 else str(i)
    keys.extend(
        [
            Key([mod], key_name, lazy.group[group.name].toscreen(), desc=f"Switch to workspace {group.name}"),
            Key([mod, "shift"], key_name, lazy.window.togroup(group.name), desc=f"Move window to {group.name}"),
        ]
    )

layouts = [
    layout.MonadTall(
        border_focus="#ffffff",
        border_normal="#414141",
        border_width=2,
        margin=8,
    ),
    layout.Max(),
    layout.Floating(border_focus="#ffffff", border_normal="#414141", border_width=2),
]

widget_defaults = dict(
    font="monospace",
    fontsize=13,
    padding=5,
)

extension_defaults = widget_defaults.copy()

wl_input_rules = {
    "type:keyboard": InputConfig(
        kb_layout="us",
        kb_variant="colemak",
        kb_options="caps:backspace",
    ),
}

screens = [
    Screen(
        top=bar.Bar(
            [
                widget.GroupBox(highlight_method="line", this_current_screen_border="#ffffff", hide_unused=True),
                widget.WindowName(),
                widget.Systray(),
                widget.Battery(format="BAT {percent:2.0%} {char}"),
                widget.Clock(format="%Y-%m-%d %a %I:%M %p"),
            ],
            28,
            background="#000000",
        ),
    )
]

mouse = [
    Drag([mod], "Button1", lazy.window.set_position_floating(), start=lazy.window.get_position()),
    Drag([mod], "Button3", lazy.window.set_size_floating(), start=lazy.window.get_size()),
    Click([mod], "Button2", lazy.window.bring_to_front()),
]

dgroups_key_binder = None
dgroups_app_rules = []
follow_mouse_focus = True
bring_front_click = False
cursor_warp = False
floating_layout = layout.Floating(
    border_focus="#ffffff",
    border_normal="#414141",
    border_width=2,
    float_rules=[
        *layout.Floating.default_float_rules,
        Match(title="branchdialog"),
        Match(title="pinentry"),
        Match(wm_class="pavucontrol"),
        Match(wm_class="blueman-manager"),
    ],
)
auto_fullscreen = True
focus_on_window_activation = "smart"
reconfigure_screens = True
auto_minimize = True

# Required for some Java UI toolkits.
wmname = "LG3D"


@hook.subscribe.startup
def autostart() -> None:
    startup_commands = [
        "xsetroot -cursor_name left_ptr",
    "bash -lc 'command -v libinput-gestures >/dev/null && (pgrep -x libinput-gestures || libinput-gestures -d)'",
        "bash -lc '[ -x ~/.config/hypr/hyprland/scripts/SynoDrive.sh ] && ~/.config/hypr/hyprland/scripts/SynoDrive.sh'",
        "bash -lc '[ -x ~/.scripts/Control-Scripts/hyprsunset-scheduler.sh ] && ~/.scripts/Control-Scripts/hyprsunset-scheduler.sh'",
        "bash -lc 'command -v nm-applet >/dev/null && nm-applet'",
        "xdg-user-dirs-update",
        "bash -lc 'command -v picom >/dev/null && picom --experimental-backends'",
        "bash -lc 'if command -v swaync >/dev/null 2>&1; then pgrep -x swaync >/dev/null || swaync; elif command -v notification-daemon >/dev/null 2>&1; then pgrep -x notification-daemon >/dev/null || notification-daemon; elif command -v dunst >/dev/null 2>&1; then pgrep -x dunst >/dev/null || dunst; fi'",
        "bash ~/.scripts/Control-Scripts/battery-notify.sh",
        "bash ~/.scripts/Control-Scripts/workspace-notify.sh",
        "bash ~/.scripts/Control-Scripts/network-notify.sh",
        "bash ~/.scripts/Control-Scripts/bluetooth-notify.sh",
        "bash -lc 'sleep 20 && ~/.scripts/Control-Scripts/update-notify.sh'",
        "gnome-keyring-daemon --start --components=secrets",
        "bash -lc 'for p in /usr/lib/polkit-kde-authentication-agent-1 /usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1 /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 /usr/libexec/polkit-gnome-authentication-agent-1 /usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1; do [ -x \"$p\" ] && exec \"$p\"; done'",
        "bash -lc 'pgrep -x pipewire >/dev/null || (command -v pipewire >/dev/null && pipewire >/dev/null 2>&1 &)'",
        "bash -lc 'pgrep -x wireplumber >/dev/null || (command -v wireplumber >/dev/null && wireplumber >/dev/null 2>&1 &)'",
        "bash -lc 'pgrep -x pipewire-pulse >/dev/null || (command -v pipewire-pulse >/dev/null && pipewire-pulse >/dev/null 2>&1 &)'",
        "bash -lc 'command -v easyeffects >/dev/null && easyeffects --gapplication-service'",
        "bash ~/.scripts/Control-Scripts/wm-clipboard-daemon.sh",
        "bash -lc 'systemctl --user list-unit-files 2>/dev/null | grep -q \"^docker-desktop.service\" && systemctl --user start docker-desktop'",
    ]

    if qtile.core.name == "x11":
        startup_commands.insert(
            0,
            "bash -lc 'command -v xcape >/dev/null && pgrep -x xcape >/dev/null || xcape -e \"Super_L=XF86Tools\"'",
        )
        startup_commands.insert(
            0,
            "bash -lc 'if xinput list | grep -q \"Goodix Capacitive TouchScreen\"; then command -v xrandr >/dev/null && for out in DSI-1 eDP-1 eDP-2; do if xrandr --query | grep -q \"^${out} connected\"; then xrandr --output \"${out}\" --rotate right; xinput set-prop \"Goodix Capacitive TouchScreen\" \"Coordinate Transformation Matrix\" 0 1 0 -1 0 1 0 0 1 2>/dev/null; break; fi; done; fi'",
        )
        startup_commands.insert(0, "setxkbmap -layout us -variant colemak -option caps:backspace")
        startup_commands.insert(0, "bash -lc 'command -v feh >/dev/null && ([ -d ~/Pictures/backgrounds ] && feh --bg-fill ~/Pictures/backgrounds/$(ls ~/Pictures/backgrounds | shuf -n1) 2>/dev/null || true)'")
    elif qtile.core.name == "wayland":
        startup_commands.insert(
            0,
            "bash -lc 'if command -v wlr-randr >/dev/null; then for _ in 1 2 3; do for out in DSI-1 eDP-1 eDP-2; do wlr-randr --output \"${out}\" --transform 90 >/dev/null 2>&1 && { xinput set-prop \"Goodix Capacitive TouchScreen\" \"Coordinate Transformation Matrix\" 0 1 0 -1 0 1 0 0 1 2>/dev/null; exit 0; }; done; sleep 1; done; fi'",
        )

    for cmd in startup_commands:
        subprocess.Popen(["bash", "-lc", cmd], env=os.environ.copy())