local terminal = "kitty"
local filemanager = "yazi"
local browser = "waterfox"
local launcher = "ulauncher"
local mainMod = "SUPER"
local shiftMod = "SHIFT"
local ctrlMod = "CTRL"
local altMod = "ALT"

-- Essentials
hl.bind(mainMod .. " + SUPER_L", hl.dsp.exec_cmd([[bash ~/.scripts/Control-Scripts/wm-app-launcher.sh]]), { release = true })
hl.bind(mainMod .. " + SUPER_R", hl.dsp.exec_cmd([[bash ~/.scripts/Control-Scripts/wm-app-launcher.sh]]), { release = true })
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.kill())
hl.bind(altMod .. " + TAB", hl.dsp.exec_cmd([[bash ~/.scripts/Control-Scripts/wm-app-launcher.sh]]))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd([[pavucontrol]]))
hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd([[XDG_CURRENT_DESKTOP="gnome" gnome-control-center]]))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd([[kitty ~/.scripts/PiercingXX-Settings-Menu/settings-menu.sh]]))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd([[bash ~/.scripts/Control-Scripts/toggle-topbar.sh]]))
hl.bind("Print", hl.dsp.exec_cmd([[~/.scripts/Control-Scripts/wm-screenshot.sh region]]))
hl.bind(shiftMod .. " + Print", hl.dsp.exec_cmd([[~/.scripts/Control-Scripts/wm-screenshot.sh window]]))
hl.bind(mainMod .. " + X", hl.dsp.layout("togglesplit"))

-- Clipboard History
hl.bind(mainMod .. " + SHIFT + Y", hl.dsp.exec_cmd([[bash ~/.scripts/Control-Scripts/wm-clipboard-menu.sh]]))

-- Notes and To-Do Lists
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd([[kitty ~/.scripts/Note-Scripts/open_daily_note.sh --split]]))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd([[kitty ~/.scripts/Note-Scripts/open_daily_note.sh --view]]))
hl.bind(mainMod .. " + ALT + N", hl.dsp.exec_cmd([[kitty ~/.scripts/Note-Scripts/open_daily_note.sh --todo]]))
hl.bind(mainMod .. " + SHIFT + ALT + N", hl.dsp.exec_cmd([[kitty ~/.scripts/Note-Scripts/open_daily_note.sh --directory]]))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd([[kitty ~/.scripts/Note-Scripts/inventory.sh]]))

-- Server Monitor
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd([[kitty -o allow_remote_control=yes -o close_on_child_death=yes ~/.scripts/Control-Scripts/launch-server-monitor.sh -monitor]]))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd([[kitty -o allow_remote_control=yes -o close_on_child_death=yes ~/.scripts/Control-Scripts/launch-server-monitor.sh -remote]]))

-- Applications
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd([[kitty tmux]]))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd([[nautilus --new-window]]))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd([[kitty yazi]]))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(browser .. [[ || flatpak run net.waterfox.waterfox]]))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd([[discord || flatpak run com.discordapp.Discord]]))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd([[opencode-desktop]]))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd([[kitty nvim]]))
hl.bind(mainMod .. " + ALT + V", hl.dsp.exec_cmd([[code]]))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd([[obsidian || flatpak run md.obsidian.Obsidian]]))
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd([[gimp || flatpak run org.gimp.GIMP]]))
hl.bind(ctrlMod .. " + ALT + Delete", hl.dsp.exec_cmd([[kitty flatpak run io.missioncenter.MissionCenter]]))
hl.bind(ctrlMod .. " + ALT + SHIFT + K", hl.dsp.exec_cmd([[sudo shutdown -h now]]))

-- Show Keybinds
hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd([[xdg-open "/home/$USER/.scripts/Control-Scripts/keybinds.html"]]))

-- Self Hosted AI
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd([[kitty ~/.scripts/Control-Scripts/launch-skippy-remote.sh]]))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd([[kitty ~/.scripts/Control-Scripts/launch-ollama-remote.sh --skippy]]))
hl.bind(mainMod .. " + ALT + A", hl.dsp.exec_cmd([[kitty ~/.scripts/Control-Scripts/launch-ollama-remote.sh --gemma]]))

-- Session
hl.bind(mainMod .. " + grave", hl.dsp.exec_cmd([[hyprlock]]))
hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.exec_cmd([[sleep 0.1 && systemctl suspend || loginctl suspend]]), { locked = true })
hl.bind(ctrlMod .. " + SHIFT + ALT + Delete", hl.dsp.exec_cmd([[systemctl poweroff || loginctl poweroff]]))

-- Workspace navigation
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + Control_L", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + ALT_L", hl.dsp.window.resize(), { mouse = true })

-- Move focus with mainMod + vim keys
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "r" }))

-- Move window with mainMod + vim keys
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "r" }))

-- Resize window with mainMod + vim keys
hl.bind(mainMod .. " + ALT + H", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
hl.bind(mainMod .. " + ALT + J", hl.dsp.window.resize({ x = 0, y = 100, relative = true }))
hl.bind(mainMod .. " + ALT + K", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
hl.bind(mainMod .. " + ALT + L", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

-- Move window with mainMod + arrow keys
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "d" }))

-- Resize window with mainMod + arrow keys
hl.bind(mainMod .. " + ALT + left", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
hl.bind(mainMod .. " + ALT + up", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
hl.bind(mainMod .. " + ALT + down", hl.dsp.window.resize({ x = 0, y = 100, relative = true }))

-- Switching
for workspace = 1, 10 do
    local key = workspace % 10
    local workspaceName = tostring(workspace)
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = workspaceName }))
end

-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for workspace = 1, 10 do
    local key = workspace % 10
    local workspaceName = tostring(workspace)
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspaceName }))
    hl.bind(mainMod .. " + ALT + " .. key, hl.dsp.window.move({ workspace = workspaceName .. " silent" }))
end

-- Media control
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl --all-players play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd([[~/.scripts/Control-Scripts/volume.sh inc]]), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd([[~/.scripts/Control-Scripts/volume.sh dec]]), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd([[pactl set-source-mute @DEFAULT_SOURCE@ toggle]]), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd([[~/.scripts/Control-Scripts/volume.sh mute]]), { locked = true })

-- Audio Output/Input Manager
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd([[bash -lc '~/.scripts/PiercingXX-Settings-Menu/audio-input-manager.sh --toggle-output']]))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd([[bash -lc '~/.scripts/Control-Scripts/notify-time.sh']]))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd([[bash -lc '~/.scripts/Control-Scripts/notify-calendar.sh']]))

-- Brightness control
hl.bind("code:232", hl.dsp.exec_cmd([[~/.scripts/Control-Scripts/brightness.sh dec]]))
hl.bind("code:233", hl.dsp.exec_cmd([[~/.scripts/Control-Scripts/brightness.sh inc]]))

-- Touchpad gestures
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({
    fingers = 3,
    direction = "up",
    action = function()
        hl.exec_cmd([[bash ~/.scripts/Control-Scripts/wm-app-launcher.sh]])
    end,
})
hl.gesture({ fingers = 4, direction = "down", action = "close" })