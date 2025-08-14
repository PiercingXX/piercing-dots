#!/bin/bash
# https://github.com/PiercingXX

# Check if running as root. If root, script will exit
if [[ $EUID -eq 0 ]]; then
    echo "This script should not be executed as root! Exiting......."
    exit 1
fi


#########################
### Window Management ###
#########################

# Clear Shortcuts
gsettings set org.gnome.settings-daemon.plugins.media-keys home "@as []"
gsettings set org.gnome.mutter.wayland.keybindings restore-shortcuts "@as []"
gsettings set org.gnome.settings-daemon.plugins.media-keys email "@as []"
gsettings set org.gnome.settings-daemon.plugins.media-keys logout "@as []"
gsettings set org.gnome.desktop.wm.keybindings switch-input-source "@as []"
gsettings set org.gnome.settings-daemon.plugins.media-keys screenreader "@as []"
gsettings set org.gnome.desktop.wm.keybindings toggle-maximized "@as []"
gsettings set org.gnome.shell.keybindings toggle-application-view "@as []"
gsettings set org.gnome.shell.keybindings toggle-message-tray "@as []"

# Custom Shortcuts
gsettings set org.gnome.desktop.wm.keybindings close "['<Super>Q']"
gsettings set org.gnome.settings-daemon.plugins.media-keys control-center "['<Super>s']"
gsettings set org.gnome.settings-daemon.plugins.media-keys screensaver "['>Super>grave']"
gsettings set org.gnome.shell.extensions.pop-shell toggle-floating "['<Super>f']"
gsettings set org.gnome.settings-daemon.plugins.media-keys home "['<Super>z']"
gsettings set org.gnome.shell.keybindings toggle-application-view "['<Super>Tab']"
gsettings set org.gnome.desktop.wm.keybindings switch-applications "['<Alt>Tab']"
gsettings set org.gnome.desktop.wm.keybindings switch-applications-backward "['<Shift><Alt>Tab']"

# Window Management Style Interface
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-1 "['<Shift><Super>1']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-2 "['<Shift><Super>2']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-3 "['<Shift><Super>3']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-4 "['<Shift><Super>4']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-5 "['<Shift><Super>5']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-6 "['<Shift><Super>6']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-7 "['<Shift><Super>7']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-8 "['<Shift><Super>8']"
gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-9 "['<Shift><Super>9']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-1 "['<Super>1']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-2 "['<Super>2']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-3 "['<Super>3']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-4 "['<Super>4']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-5 "['<Super>5']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-6 "['<Super>6']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-7 "['<Super>7']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-8 "['<Super>8']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-9 "['<Super>9']"
# Alt for Pinned apps
gsettings set org.gnome.shell.keybindings switch-to-application-1 "['<Alt>1']"
gsettings set org.gnome.shell.keybindings switch-to-application-2 "['<Alt>2']"
gsettings set org.gnome.shell.keybindings switch-to-application-3 "['<Alt>3']"
gsettings set org.gnome.shell.keybindings switch-to-application-4 "['<Alt>4']"
gsettings set org.gnome.shell.keybindings switch-to-application-5 "['<Alt>5']"
gsettings set org.gnome.shell.keybindings switch-to-application-6 "['<Alt>6']"
gsettings set org.gnome.shell.keybindings switch-to-application-7 "['<Alt>7']"
gsettings set org.gnome.shell.keybindings switch-to-application-8 "['<Alt>8']"
gsettings set org.gnome.shell.keybindings switch-to-application-9 "['<Alt>9']"

# Reserve slots for custom keybindings
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom7/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom8/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom9/']"
# 0 Internet Browser
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Firefox'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 'firefox'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>c'
# 1 Terminal
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ name 'terminal'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ command 'gnome-terminal'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding '<Super>W'
# 2 Ulauncher
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ name 'Ulauncher'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ command 'ulauncher-toggle'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ binding '<Super>space'
# 3 Obsidian
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/ name 'Obsidian'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/ command 'flatpak run md.obsidian.Obsidian'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/ binding '<Super>b'
# 4 Mission Center
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/ name 'Mission Center'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/ command 'flatpak run io.missioncenter.MissionCenter'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/ binding '<Control><Alt>Delete'
# 5 Emoji
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/ name 'Emoji'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/ command 'flatpak run com.tomjwatson.Emote'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/ binding '<Super>period'
# 6 VScode
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/ name 'Nvim'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/ command 'vi'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/ binding '<Super>V'
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
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom9/ command 'kitty ollama run gemma3n:latest'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom9/ binding '<Super>a'


######################
### Customizations ###
######################

# Customizations
#gsettings set org.gnome.desktop.interface enable-animations 'false'
gsettings set org.gnome.desktop.interface clock-format '24h'
gsettings set org.gnome.desktop.interface clock-show-weekday 'true'
gsettings set org.gnome.desktop.peripherals.keyboard numlock-state 'true'
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
dconf write /org/gnome/desktop/privacy/recent-files-max-age "1"
dconf write /org/gnome/desktop/privacy/remove-old-trash-files "true"
dconf write /org/gnome/desktop/privacy/remove-old-temp-files "true"
dconf write /org/gnome/desktop/privacy/old-files-age "1"

# Enable X11 Keyboard Varients in Wayland
gsettings set org.gnome.desktop.input-sources show-all-sources 'true'

# Power & Display Settings
#dconf write /org/gnome/shell/last-selected-power-profile "'performance'"
gsettings set org.gnome.desktop.interface show-battery-percentage 'true'
#gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled 'false'
#gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'interactive'
#gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'suspend'
#gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout '7200'
#gsettings set org.gnome.desktop.session idle-delay 'uint32 900'

# Fractional scaling
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"

# Icons & Cursor
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'
gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus'

# Mouse & Touchpad Settings
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:backspace']"
gsettings set org.gnome.desktop.peripherals.mouse speed '0.1'
gsettings set org.gnome.desktop.peripherals.touchpad speed '0.1'
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click 'true'
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll 'true'
gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled 'true'
gsettings set org.gnome.desktop.peripherals.touchpad click-method 'fingers'

# Fonts
#gsettings set org.gnome.desktop.interface font-name 'FiraCode Nerd Font Medium 10'
#gsettings set org.gnome.desktop.interface document-font-name 'FiraCode Nerd Font 10'
#gsettings set org.gnome.desktop.interface monospace-font-name 'FiraCode Nerd Font Mono Light 10'
#gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Adwaita Sans Bold 11'

# Night Light
gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled 'true'
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-automatic 'false'
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-from '20'
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-to '04'
gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature '2500'

echo -e "${BLUE}PiercingXX's Rice Applied!${NC}"
