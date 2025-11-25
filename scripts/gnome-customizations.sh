#!/bin/bash
# https://github.com/PiercingXX

# Check if running as root. If root, script will exit
if [[ $EUID -eq 0 ]]; then
    echo "This script should not be executed as root! Exiting......."
    exit 1
fi


#######################
### Clear Shortcuts ###
#######################
gsettings set org.gnome.mutter.wayland.keybindings restore-shortcuts "@as []"
gsettings set org.gnome.settings-daemon.plugins.media-keys home "@as []"
gsettings set org.gnome.settings-daemon.plugins.media-keys email "@as []"
gsettings set org.gnome.settings-daemon.plugins.media-keys logout "@as []"
gsettings set org.gnome.settings-daemon.plugins.media-keys www "@as []"
gsettings set org.gnome.settings-daemon.plugins.media-keys control-center "@as []"
gsettings set org.gnome.settings-daemon.plugins.media-keys screenreader "@as []"
gsettings set org.gnome.settings-daemon.plugins.media-keys screensaver "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-input-source "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-group "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-group-backward "@as []"
gsettings set org.gnome.desktop.wm.keybindings toggle-maximized "@as []"
gsettings set org.gnome.shell.keybindings toggle-application-view "@as []"
gsettings set org.gnome.shell.keybindings toggle-message-tray "@as []"
gsettings set org.gnome.shell.keybindings focus-active-notification "@as []"
gsettings set org.gnome.shell.keybindings toggle-quick-settings "@as []"
gsettings set org.gnome.shell.extensions.space-bar.shortcuts open-menu "@as []"
gsettings set org.gnome.shell.extensions.pop-shell toggle-stacking "@as []"
gsettings set org.gnome.shell.extensions.pop-shell toggle-stacking-global "@as []"
gsettings set org.gnome.shell.extensions.pop-shell toggle-tiling "@as []"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-1 "@as []"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-2 "@as []"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-3 "@as []"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-4 "@as []"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-5 "@as []"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-6 "@as []"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-7 "@as []"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-8 "@as []"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-9 "@as []"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-10 "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-to-application-1 "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-to-application-2 "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-to-application-3 "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-to-application-4 "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-to-application-5 "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-to-application-6 "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-to-application-7 "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-to-application-8 "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-to-application-9 "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-to-application-10 "@as []"

#############################
### Workspace Keybindings ###
#############################
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-1 "<Super>1"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-2 "<Super>2"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-3 "<Super>3"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-4 "<Super>4"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-5 "<Super>5"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-6 "<Super>6"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-7 "<Super>7"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-8 "<Super>8"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-9 "<Super>9"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-10 "<Super>0"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-1 "<Shift><Super>1"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-2 "<Shift><Super>2"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-3 "<Shift><Super>3"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-4 "<Shift><Super>4"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-5 "<Shift><Super>5"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-6 "<Shift><Super>6"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-7 "<Shift><Super>7"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-8 "<Shift><Super>8"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-9 "<Shift><Super>9"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-10 "<Shift><Super>0"

##########################
### Custom Keybindings ###
##########################
gsettings set org.gnome.desktop.wm.keybindings close "['<Super>Q']"
gsettings set org.gnome.shell.keybindings toggle-application-view "['<Super>Tab']"
gsettings set org.gnome.settings-daemon.plugins.media-keys screensaver "['<Super>grave']"
gsettings set org.gnome.settings-daemon.plugins.media-keys home "['<Shift><Super>z']"
gsettings set org.gnome.settings-daemon.plugins.media-keys calculator "['<Shift><Super>c']"
gsettings set org.gnome.desktop.wm.keybindings toggle-fullscreen "['<Super>f']"
gsettings set org.gnome.desktop.wm.keybindings switch-applications "['<Alt>Tab']"
gsettings set org.gnome.desktop.wm.keybindings switch-applications-backward "['<Shift><Alt>Tab']"
# Reserve slots for custom keybindings
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom7/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom8/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom9/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom11/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom12/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom13/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom14/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom15/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom16/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom17/']"
# 0 Waterfox
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Waterfox'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'flatpak run net.waterfox.waterfox'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>c'
# 1 Kitty
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ name 'kitty'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ command 'kitty'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding '<Super>W'
# 2 Yazi
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ name 'Yazi'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ command 'kitty -- yazi'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ binding '<Super>z'
# 3 Neovim
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/ name 'Neovim'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/ command 'kitty -- nvim'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/ binding '<Super>V'
# 4 Mission Center
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/ name 'Mission Center'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/ command 'flatpak run io.missioncenter.MissionCenter'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/ binding '<Control><Alt>Delete'
# 5 Obsidian
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/ name 'Obsidian'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/ command 'flatpak run md.obsidian.Obsidian'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/ binding '<Super>b'
# 6 VScode
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/ name 'VScode'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/ command 'code'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/ binding '<Shift><Super>V'
# 7 GIMP
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom7/ name 'Gimp'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom7/ command 'flatpak run org.gimp.GIMP'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom7/ binding '<Super>g'
# 8 Discord
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom8/ name 'Discord'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom8/ command 'flatpak run com.discordapp.Discord'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom8/ binding '<Super>d'
# 9 Run Local AI
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom9/ name 'AI'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom9/ command 'kitty bash -c '.scripts/Control-Scripts/launch_ollama_ssh.sh''
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom9/ binding '<Super>a'
# 10 Shutdown
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/ name 'Shutdown'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/ command 'sudo shutdown -h now'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/ binding '<Control><Alt><Shift>k'
# 11 Open Daily Notes
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom11/ name 'Edit Daily Notes'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom11/ command 'kitty bash -c '~/.scripts/Note-Scripts/open_daily_note.sh --view''
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom11/ binding '<Shift><Super>n'
# 12 Open Daily Notes
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom12/ name 'View Daily Notes'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom12/ command 'kitty bash -c '~/.scripts/Note-Scripts/open_daily_note.sh --todo''
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom12/ binding '<Alt><Super>n'
# 13 Open Yazi in Daily Notes Directory
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom13/ name 'Open Yazi in Daily Notes Directory'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom13/ command 'kitty bash -c '~/.scripts/Note-Scripts/open_daily_note.sh --split''
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom13/ binding '<Super>n'
# 14 Audio Output Switcher
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom17/ name 'Audio Output Switcher'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom17/ command 'bash ~/.scripts/PiercingXX-Settings-Menu/audio-input-manager.sh --toggle-output'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom17/ binding '<Super>o'
# 15 Open Inventory Directory
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom15/ name 'Open Inventory Directory'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom15/ command 'kitty bash -c '~/.scripts/Note-Scripts/inventory.sh''
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom15/ binding '<Super>i'
# 16 Settings TUI Menu
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom16/ name 'Settings Menu'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom16/ command 'kitty bash -c '~/.scripts/PiercingXX-Settings-Menu/settings-menu.sh''
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom16/ binding '<Super>s'
# 17 Cheat Sheet
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom17/ name 'Cheat Sheet'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom17/ command 'kitty w3m '~/.scripts/Control-Scripts/keybinds.html''
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom17/ binding '<Super>slash'


######################
### Customizations ###
######################
gsettings set org.gnome.settings-daemon.plugins.housekeeping.donation-reminder-enabled 'false'
gsettings set org.gnome.desktop.notifications show-banners 'false'
gsettings set org.gnome.desktop.interface enable-animations 'false'
gsettings set org.gnome.desktop.interface clock-format '24h'
gsettings set org.gnome.desktop.interface clock-show-weekday 'true'
gsettings set org.gnome.desktop.peripherals.keyboard numlock-state 'true'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface enable-hot-corners 'false'
gsettings set org.gnome.desktop.background picture-options 'zoom'
gsettings set org.gnome.shell.mutter edge-tiling 'false'
gsettings set org.gnome.settings-daemon.peripherals.touchscreen orientation-lock false
dconf write /org/gnome/system/location/enabled 'false'
dconf write /org/gnome/desktop/privacy/report-technical-problems 'false'
dconf write /org/gnome/desktop/a11y/applications/screen-reader-enabled 'false'
dconf write /org/gnome/desktop/interface/toolkit-accessibility 'false'
dconf write /org/gnome/shell/ubuntu/startup-sound "''"
dconf write /org/gnome/desktop/wm/preferences/button-layout "'appmenu:close'"
dconf write /org/gnome/system/location/enabled "'false'"
dconf write /org/gnome/desktop/privacy/recent-files-max-age "1"
dconf write /org/gnome/desktop/privacy/remove-old-trash-files "true"
dconf write /org/gnome/desktop/privacy/remove-old-temp-files "true"
dconf write /org/gnome/desktop/privacy/old-files-age "1"
dconf write /org/gnome/mutter/workspaces-only-on-primary "true"

# Enable X11 Keyboard Varients in Wayland
gsettings set org.gnome.desktop.input-sources show-all-sources 'true'

# Power & Display Settings
dconf write /org/gnome/shell/last-selected-power-profile "'performance'"
gsettings set org.gnome.desktop.interface show-battery-percentage 'true'
gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled 'false'
gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'interactive'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'suspend'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout '3600'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout '1800'
gsettings set org.gnome.settings-daemon.plugins.power idle-dim 'false'
gsettings set org.gnome.desktop.session idle-delay 'uint32 900'

# Fractional scaling
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"

# Icons & Cursor
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus'

# Mouse & Touchpad Settings
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:backspace']"
gsettings set org.gnome.desktop.peripherals.mouse speed '0.1'
gsettings set org.gnome.desktop.peripherals.mouse accel-profile 'flat'
gsettings set org.gnome.desktop.peripherals.touchpad accel-profile 'flat'
gsettings set org.gnome.desktop.peripherals.touchpad speed '0.1'
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click 'true'
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll 'true'
gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled 'true'
gsettings set org.gnome.desktop.peripherals.touchpad click-method 'fingers'

# Focus Follows Mouse Instant
gsettings set org.gnome.mutter focus-change-on-pointer-rest false
gsettings set org.gnome.shell.extensions.pop-shell mouse-cursor-focus-location 'uint32 0'
gsettings set org.gnome.shell.extensions.pop-shell mouse-cursor-follows-active-window true
gsettings set org.gnome.desktop.wm.preferences auto-raise-delay '200'
dconf write /org/gnome/desktop/wm/preferences/focus-mode "'mouse'"
dconf write /org/gnome/desktop/wm/preferences/auto-raise "'false'"

# Fonts
gsettings set org.gnome.desktop.interface font-name 'FiraCode Nerd Font Medium 10'
gsettings set org.gnome.desktop.interface document-font-name 'FiraCode Nerd Font 10'
gsettings set org.gnome.desktop.interface monospace-font-name 'FiraCode Nerd Font Mono Light 10'
gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Adwaita Sans Bold 11'

# Night Light
gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled 'true'
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-automatic 'false'
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-from '20'
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-to '04'
gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature '2300'

# Gnome Shell Icon List
gsettings set org.gnome.shell favorite-apps "['net.waterfox.waterfox.desktop', 'waterfox.desktop', 'org.gnome.Nautilus.desktop', 'org.libreoffice.LibreOffice.writer.desktop', 'org.gnome.Calculator.desktop', 'md.obsidian.Obsidian.desktop', 'com.visualstudio.code.desktop', 'code.desktop', 'synochat.desktop', 'org.gimp.GIMP.desktop', 'org.blender.Blender.desktop']"


##################
### Extensions ###
##################

# Enable Extensions
for ext in $(gnome-extensions list); do gnome-extensions enable "$ext"; done

# Pop Shell
gsettings set org.gnome.shell.extensions.pop-shell toggle-floating "['<Shift><Super>f']"
dconf write /org/gnome/shell/extensions/pop-cosmic/show-workspaces-button 'false'
dconf write /org/gnome/shell/extensions/pop-cosmic/show-applications-button 'false'
dconf write /org/gnome/shell/extensions/pop-shell/hint-color-rgba "'rgb(255,255,255)'"
gsettings set org.gnome.shell.extensions.pop-shell stacking-with-mouse false
gsettings set org.gnome.shell.extensions.pop-shell active-hint-border-radius 'uint32 7'
gsettings set org.gnome.shell.extensions.pop-shell gap-inner 'uint32 4'
gsettings set org.gnome.shell.extensions.pop-shell gap-outer 'uint32 6'
gsettings set org.gnome.shell.extensions.pop-shell tile-orientation "['<Super>x']"
gsettings set org.gnome.shell.extensions.pop-shell toggle-floating "['<Super>f']"
gsettings set org.gnome.shell.extensions.pop-shell active-hint 'true'
gsettings set org.gnome.shell.mutter edge-tiling 'false'
gsettings set org.gnome.shell.extensions.pop-shell tile-by-default 'true'

# Super Key
dconf write /org/gnome/shell/extensions/super-key/overlay/key/action "'ulauncher'"
gsettings set org.gnome.shell.extensions.super-key overlay-key 'ulauncher'

# Useless Gaps
dconf write /org/gnome/shell/extensions/useless-gaps/gap-size "20"

# Just Perfection
dconf write /org/gnome/shell/extensions/just-perfection/dash-icon-size "48"
dconf write /org/gnome/shell/extensions/just-perfection/animation "3"
dconf write /org/gnome/shell/extensions/just-perfection/startup-status "0"
dconf write /org/gnome/shell/extensions/just-perfection/app-menu-icon "false"
dconf write /org/gnome/shell/extensions/just-perfection/activities-button "false"
dconf write /org/gnome/shell/extensions/just-perfection/app-menu "false"
dconf write /org/gnome/shell/extensions/just-perfection/app-menu-label "false"
dconf write /org/gnome/shell/extensions/just-perfection/search "false"
dconf write /org/gnome/shell/extensions/just-perfection/theme "true"

# Caffeine
dconf write /org/gnome/shell/extensions/caffeine/duration-timer "4"

# Awesome Tiles
dconf write /org/gnome/shell/extensions/awesome-tiles/gap-size-increments "1"

# AZ Taskbar
dconf write /org/gnome/shell/extensions/aztaskbar/favorites "false"
dconf write /org/gnome/shell/extensions/aztaskbar/main-panel-height "33"
dconf write /org/gnome/shell/extensions/aztaskbar/panel-on-all-monitors "false"
dconf write /org/gnome/shell/extensions/aztaskbar/show-panel-activities-button "false"
dconf write /org/gnome/shell/extensions/aztaskbar/icon-size "23"
dconf write /org/gnome/shell/extensions/aztaskbar/hide-dash "false"
dconf write /org/gnome/shell/extensions/aztaskbar/indicator-color-focused "'rgb(246,148,255)'"
dconf write /org/gnome/shell/extensions/aztaskbar/indicator-color-running "'rgb(130,226,255)'"

# Blur My Shell
dconf write /org/gnome/shell/extensions/blur-my-shell/brightness "1.0"

# Space Bar
dconf write /org/gnome/shell/extensions/space-bar/behavior/show-empty-workspaces 'false'
dconf write /org/gnome/shell/extensions/space-bar/behavior/toggle-overview 'false'
dconf write /org/gnome/shell/extensions/space-bar/shortcuts/enable-move-to-workspace-shortcuts 'true'

# Forge
dconf write /org/gnome/shell/extensions/forge/stacked-tiling-mode-enabled 'false'
dconf write /org/gnome/shell/extensions/forge/tabbed-tiling-mode-enabled 'false'
dconf write /org/gnome/shell/extensions/forge/preview-hint-enabled 'false'
dconf write /org/gnome/shell/extensions/forge/window-gap-size 'uint32 7'
dconf write /org/gnome/shell/extensions/forge/move-pointer-focus-enabled 'true'

# Workspace buttons with App Icons
dconf write /org/gnome/shell/extensions/workspace-buttons-with-app-icons/top-bar-height "27"
dconf write /org/gnome/shell/extensions/workspace-buttons-with-app-icons/wsb-ws-num-font-size "16"
dconf write /org/gnome/shell/extensions/workspace-buttons-with-app-icons/wsb-ws-num-active-color "'rgba(255, 255, 255, 0.39)'"
dconf write /org/gnome/shell/extensions/workspace-buttons-with-app-icons/wsb-ws-app-icons-wrapper-active-color "'rgba(255, 255, 255, 0.39)'"
dconf write /org/gnome/shell/extensions/workspace-buttons-with-app-icons/wsb-ws-btn-border-active-color "'rgba(255, 255, 255, 1)'"

# Nautilus Open Any Terminal
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal 'kitty'
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal new-tab 'true'
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal flatpak 'system'

# Disable Extensions
gnome-extensions disable 'cosmic-dock@system76.com'
gnome-extensions disable 'cosmic-workspaces@system76.com'
gnome-extensions disable 'popx11gestures@system76.com'
gnome-extensions disable 'ding@rastersoft.com'
gnome-extensions disable 'pop-cosmic@system76.com'
gnome-extensions disable 'apps-menu@gnome-shell-extensions.gcampax.github.com'
gnome-extensions disable 'background-logo@fedorahosted.org'
gnome-extensions disable 'tiling-assistant@ubuntu.com'
gnome-extensions disable 'ubuntu-dock@ubuntu.com'
gnome-extensions disable 'ding@rastersoft.com'

# Enable Extensions *** This currently isn't working until the shell is restarted...Re-run after reboot to finalize***
gnome-extensions enable 'ubuntu-appindicators@ubuntu.com'
gnome-extensions enable 'gsconnect@andyholmes.github.io'
gnome-extensions enable 'aztaskbar@aztaskbar.gitlab.com'
gnome-extensions enable 'blur-my-shell@aunetx'
gnome-extensions enable 'caffeine@patapon.info'
gnome-extensions enable 'just-perfection-desktop@just-perfection'
gnome-extensions enable 'appindicatorsupport@rgcjonas.gmail.com'
gnome-extensions enable 'forge@jmmaranan.com'
gnome-extensions enable 'pop-shell@system76.com'
gnome-extensions enable 'useless-gaps@pimsnel.com'
gnome-extensions enable 'system76-power@system76.com'
gnome-extensions enable 'awesome-tiles@velitasali.com'
gnome-extensions enable 'workspace-buttons-with-app-icons@miro011.github.com'
gnome-extensions enable 'super-key@tommimon.github.com'

echo -e "${BLUE}PiercingXX's Rice Applied!${NC}"
