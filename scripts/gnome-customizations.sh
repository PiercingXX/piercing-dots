#!/usr/bin/env bash
# https://github.com/PiercingXX
#
# PiercingXX GNOME rice: keybindings, preferences and extension settings.
# Every setting is skipped quietly when its schema/key or extension isn't
# installed, so this runs cleanly on Arch, Debian/Ubuntu/Pop, Fedora, etc.

BLUE=$'\033[0;34m'
YELLOW=$'\033[1;33m'
NC=$'\033[0m'

# Check if running as root. If root, script will exit
if [[ $EUID -eq 0 ]]; then
    echo "This script should not be executed as root! Exiting......."
    exit 1
fi

if ! command -v gsettings >/dev/null 2>&1 || ! command -v dconf >/dev/null 2>&1; then
    echo "GNOME customization tools are unavailable; skipping."
    exit 0
fi

if [[ -z ${DBUS_SESSION_BUS_ADDRESS:-} ]] || [[ -z ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]]; then
    echo "No active GNOME session bus/display detected; skipping GNOME customizations."
    exit 0
fi

# gset SCHEMA[:PATH] KEY VALUE : set only when this GNOME version has the key
gset() {
    gsettings writable "$1" "$2" >/dev/null 2>&1 || return 0
    gsettings set "$@" || echo -e "${YELLOW}gsettings set $1 $2 failed${NC}"
}

ext_installed() {
    command -v gnome-extensions >/dev/null 2>&1 && gnome-extensions info "$1" >/dev/null 2>&1
}

# ext_gset UUID SCHEMA KEY VALUE : extension schemas live inside the extension
# dir (user or system), which gsettings doesn't search by default.
ext_gset() {
    local uuid="$1"; shift
    local dir
    for dir in "$HOME/.local/share/gnome-shell/extensions/$uuid/schemas" \
               "/usr/share/gnome-shell/extensions/$uuid/schemas"; do
        if [[ -f "$dir/gschemas.compiled" ]]; then
            gsettings --schemadir "$dir" writable "$1" "$2" >/dev/null 2>&1 || return 0
            gsettings --schemadir "$dir" set "$@" || echo -e "${YELLOW}gsettings set $1 $2 failed${NC}"
            return 0
        fi
    done
    gset "$@"
}

ext_enable()  { ext_installed "$1" && gnome-extensions enable "$1"; return 0; }
ext_disable() { ext_installed "$1" && gnome-extensions disable "$1"; return 0; }


#######################
### Clear Shortcuts ###
#######################
gset org.gnome.mutter.wayland.keybindings restore-shortcuts "@as []"
gset org.gnome.settings-daemon.plugins.media-keys home "@as []"
gset org.gnome.settings-daemon.plugins.media-keys email "@as []"
gset org.gnome.settings-daemon.plugins.media-keys logout "@as []"
gset org.gnome.settings-daemon.plugins.media-keys www "@as []"
gset org.gnome.settings-daemon.plugins.media-keys control-center "@as []"
gset org.gnome.settings-daemon.plugins.media-keys screenreader "@as []"
gset org.gnome.settings-daemon.plugins.media-keys screensaver "@as []"
gset org.gnome.desktop.wm.keybindings switch-input-source "@as []"
gset org.gnome.desktop.wm.keybindings switch-group "@as []"
gset org.gnome.desktop.wm.keybindings switch-group-backward "@as []"
gset org.gnome.desktop.wm.keybindings toggle-maximized "@as []"
gset org.gnome.shell.keybindings toggle-application-view "@as []"
gset org.gnome.shell.keybindings toggle-message-tray "@as []"
gset org.gnome.shell.keybindings focus-active-notification "@as []"
gset org.gnome.shell.keybindings toggle-quick-settings "@as []"
# Extension-specific keybindings (only if extensions are installed)
ext_gset pop-shell@system76.com org.gnome.shell.extensions.pop-shell toggle-stacking "@as []"
ext_gset pop-shell@system76.com org.gnome.shell.extensions.pop-shell toggle-stacking-global "@as []"
ext_gset pop-shell@system76.com org.gnome.shell.extensions.pop-shell toggle-tiling "@as []"
gset org.gnome.desktop.wm.keybindings move-to-workspace-1 "@as []"
gset org.gnome.desktop.wm.keybindings move-to-workspace-2 "@as []"
gset org.gnome.desktop.wm.keybindings move-to-workspace-3 "@as []"
gset org.gnome.desktop.wm.keybindings move-to-workspace-4 "@as []"
gset org.gnome.desktop.wm.keybindings move-to-workspace-5 "@as []"
gset org.gnome.desktop.wm.keybindings move-to-workspace-6 "@as []"
gset org.gnome.desktop.wm.keybindings move-to-workspace-7 "@as []"
gset org.gnome.desktop.wm.keybindings move-to-workspace-8 "@as []"
gset org.gnome.desktop.wm.keybindings move-to-workspace-9 "@as []"
gset org.gnome.desktop.wm.keybindings move-to-workspace-10 "@as []"
gset org.gnome.shell.keybindings switch-to-application-1 "@as []"
gset org.gnome.shell.keybindings switch-to-application-2 "@as []"
gset org.gnome.shell.keybindings switch-to-application-3 "@as []"
gset org.gnome.shell.keybindings switch-to-application-4 "@as []"
gset org.gnome.shell.keybindings switch-to-application-5 "@as []"
gset org.gnome.shell.keybindings switch-to-application-6 "@as []"
gset org.gnome.shell.keybindings switch-to-application-7 "@as []"
gset org.gnome.shell.keybindings switch-to-application-8 "@as []"
gset org.gnome.shell.keybindings switch-to-application-9 "@as []"

#############################
### Workspace Keybindings ###
#############################
gset org.gnome.desktop.wm.keybindings switch-to-workspace-1 "['<Super>1']"
gset org.gnome.desktop.wm.keybindings switch-to-workspace-2 "['<Super>2']"
gset org.gnome.desktop.wm.keybindings switch-to-workspace-3 "['<Super>3']"
gset org.gnome.desktop.wm.keybindings switch-to-workspace-4 "['<Super>4']"
gset org.gnome.desktop.wm.keybindings switch-to-workspace-5 "['<Super>5']"
gset org.gnome.desktop.wm.keybindings switch-to-workspace-6 "['<Super>6']"
gset org.gnome.desktop.wm.keybindings switch-to-workspace-7 "['<Super>7']"
gset org.gnome.desktop.wm.keybindings switch-to-workspace-8 "['<Super>8']"
gset org.gnome.desktop.wm.keybindings switch-to-workspace-9 "['<Super>9']"
gset org.gnome.desktop.wm.keybindings switch-to-workspace-10 "['<Super>0']"
gset org.gnome.desktop.wm.keybindings move-to-workspace-1 "['<Shift><Super>1']"
gset org.gnome.desktop.wm.keybindings move-to-workspace-2 "['<Shift><Super>2']"
gset org.gnome.desktop.wm.keybindings move-to-workspace-3 "['<Shift><Super>3']"
gset org.gnome.desktop.wm.keybindings move-to-workspace-4 "['<Shift><Super>4']"
gset org.gnome.desktop.wm.keybindings move-to-workspace-5 "['<Shift><Super>5']"
gset org.gnome.desktop.wm.keybindings move-to-workspace-6 "['<Shift><Super>6']"
gset org.gnome.desktop.wm.keybindings move-to-workspace-7 "['<Shift><Super>7']"
gset org.gnome.desktop.wm.keybindings move-to-workspace-8 "['<Shift><Super>8']"
gset org.gnome.desktop.wm.keybindings move-to-workspace-9 "['<Shift><Super>9']"
gset org.gnome.desktop.wm.keybindings move-to-workspace-10 "['<Shift><Super>0']"

##########################
### Custom Keybindings ###
##########################
gset org.gnome.desktop.wm.keybindings close "['<Super>Q']"
gset org.gnome.shell.keybindings toggle-application-view "['<Super>Tab']"
gset org.gnome.settings-daemon.plugins.media-keys screensaver "['<Super>grave']"
gset org.gnome.settings-daemon.plugins.media-keys home "['<Shift><Super>z']"
gset org.gnome.settings-daemon.plugins.media-keys calculator "['<Shift><Super>c']"
gset org.gnome.desktop.wm.keybindings toggle-fullscreen "['<Super>f']"
gset org.gnome.desktop.wm.keybindings switch-applications "['<Alt>Tab']"
gset org.gnome.desktop.wm.keybindings switch-applications-backward "['<Shift><Alt>Tab']"

ALL_CUSTOM_PATHS="['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom7/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom8/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom9/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom11/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom12/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom13/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom14/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom15/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom16/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom17/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom18/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom19/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom20/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom21/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom22/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom23/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom24/']"
gset org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$ALL_CUSTOM_PATHS"

# 0 Waterfox
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Waterfox'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command "flatpak run net.waterfox.waterfox"
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>c'
# 1 Kitty
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ name 'kitty'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ command 'kitty'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding '<Super>W'
# 2 Yazi
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ name 'Yazi'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ command "kitty -- yazi"
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ binding '<Super>z'
# 3 Neovim
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/ name 'Neovim'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/ command "kitty -- nvim"
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/ binding '<Super>V'
# 4 Mission Center
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/ name 'Mission Center'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/ command "flatpak run io.missioncenter.MissionCenter"
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/ binding '<Control><Alt>Delete'
# 5 Obsidian
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/ name 'Obsidian'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/ command "flatpak run md.obsidian.Obsidian"
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/ binding '<Super>b'
# 6 VScode
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/ name 'VScode'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/ command 'code'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom6/ binding '<Shift><Super>V'
# 7 GIMP
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom7/ name 'Gimp'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom7/ command "flatpak run org.gimp.GIMP"
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom7/ binding '<Super>g'
# 8 Discord
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom8/ name 'Discord'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom8/ command "flatpak run com.discordapp.Discord"
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom8/ binding '<Super>d'
# 9 Run Local AI (Skippy)
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom9/ name 'AI Skippy'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom9/ command "kitty bash -c \"~/.scripts/Control-Scripts/launch-ollama-remote.sh --skippy\""
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom9/ binding '<Super>a'
# 10 Shutdown
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/ name 'Shutdown'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/ command 'systemctl poweroff'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/ binding '<Control><Alt><Shift>k'
# 11 Open Daily Notes
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom11/ name 'View Daily Notes'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom11/ command "kitty bash -c \"~/.scripts/Note-Scripts/open_daily_note.sh --view\""
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom11/ binding '<Shift><Super>n'
# 12 Open Daily Notes
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom12/ name 'View Todo'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom12/ command "kitty bash -c \"~/.scripts/Note-Scripts/open_daily_note.sh --todo\""
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom12/ binding '<Alt><Super>n'
# 13 Open Yazi in Daily Notes Directory
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom13/ name 'Open Notes To Edit'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom13/ command "kitty bash -c \"~/.scripts/Note-Scripts/open_daily_note.sh --split\""
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom13/ binding '<Super>n'
# 14 Audio Output Switcher
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom14/ name 'Audio Output Switcher'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom14/ command "bash ~/.scripts/PiercingXX-Settings-Menu/audio-input-manager.sh --toggle-output"
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom14/ binding '<Super>o'
# 15 Open Inventory Directory
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom15/ name 'Open Inventory Directory'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom15/ command "kitty bash -c \"~/.scripts/Note-Scripts/inventory.sh\""
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom15/ binding '<Super>i'
# 16 Settings TUI Menu
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom16/ name 'Settings Menu'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom16/ command "kitty bash -c \"~/.scripts/PiercingXX-Settings-Menu/settings-menu.sh\""
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom16/ binding '<Super>s'
# 17 Cheat Sheet
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom17/ name 'Cheat Sheet'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom17/ command "kitty w3m ~/.scripts/Control-Scripts/keybinds.html"
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom17/ binding '<Super>slash'
# 18 Monitor Server
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom18/ name 'Server Monitor'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom18/ command "kitty -o allow_remote_control=yes bash -c \"~/.scripts/Control-Scripts/launch-server-monitor.sh -monitor\""
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom18/ binding '<Super>M'
# 19 Remote Monitor
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom19/ name 'Server Log'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom19/ command "kitty bash -c \"~/.scripts/Control-Scripts/launch-server-monitor.sh -log\""
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom19/ binding '<Shift><Super>M'
# 20 AI GPT-OSS
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom20/ name 'AI GPT-OSS'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom20/ command "kitty bash -c \"~/.scripts/Control-Scripts/launch-ollama-remote.sh --gpt\""
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom20/ binding '<Shift><Super>a'
# 21 AI Gemma
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom21/ name 'AI Gemma'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom21/ command "kitty bash -c \"~/.scripts/Control-Scripts/launch-ollama-remote.sh --gemma\""
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom21/ binding '<Alt><Super>a'
# 22 Open Yazi in Daily Notes Directory
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom22/ name 'Open Notes Directory'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom22/ command "kitty bash -c \"~/.scripts/Note-Scripts/open_daily_note.sh --directory\""
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom22/ binding '<Shift><Alt><Super>n'
# 23 GNOME Control Center
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom23/ name 'GNOME Control Center'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom23/ command 'XDG_CURRENT_DESKTOP="gnome" gnome-control-center'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom23/ binding '<Alt><Super>s'
# 24 Tmux
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom24/ name 'Tmux'
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom24/ command "kitty -- tmux"
gset org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom24/ binding '<Super>t'

######################
### Customizations ###
######################
gset org.gnome.settings-daemon.plugins.housekeeping donation-reminder-enabled false
gset org.gnome.desktop.notifications show-banners 'false'
gset org.gnome.desktop.interface enable-animations 'false'
gset org.gnome.desktop.interface clock-format '24h'
gset org.gnome.desktop.interface clock-show-weekday 'true'
gset org.gnome.desktop.peripherals.keyboard numlock-state 'true'
gset org.gnome.desktop.interface color-scheme 'prefer-dark'
gset org.gnome.desktop.interface enable-hot-corners 'false'
gset org.gnome.desktop.background picture-options 'zoom'
gset org.gnome.mutter edge-tiling 'false'
gset org.gnome.settings-daemon.peripherals.touchscreen orientation-lock false
dconf write /org/gnome/system/location/enabled 'false'
dconf write /org/gnome/desktop/privacy/report-technical-problems 'false'
dconf write /org/gnome/desktop/a11y/applications/screen-reader-enabled 'false'
dconf write /org/gnome/desktop/interface/toolkit-accessibility 'false'
# Ubuntu-only key; harmless elsewhere
dconf write /org/gnome/shell/ubuntu/startup-sound "''"
dconf write /org/gnome/desktop/wm/preferences/button-layout "'appmenu:close'"
dconf write /org/gnome/desktop/privacy/recent-files-max-age "1"
dconf write /org/gnome/desktop/privacy/remove-old-trash-files "true"
dconf write /org/gnome/desktop/privacy/remove-old-temp-files "true"
dconf write /org/gnome/desktop/privacy/old-files-age "1"
dconf write /org/gnome/mutter/workspaces-only-on-primary "true"

# Enable X11 Keyboard Varients in Wayland
gset org.gnome.desktop.input-sources show-all-sources 'true'

# Power & Display Settings
dconf write /org/gnome/shell/last-selected-power-profile "'performance'"
gset org.gnome.desktop.interface show-battery-percentage 'true'
gset org.gnome.settings-daemon.plugins.power ambient-enabled 'false'
gset org.gnome.settings-daemon.plugins.power power-button-action 'interactive'
gset org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'suspend'
gset org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout '3600'
gset org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout '1800'
gset org.gnome.settings-daemon.plugins.power idle-dim 'false'
gset org.gnome.desktop.session idle-delay 'uint32 900'

# Fractional scaling
gset org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"

# Icons & Cursor
gset org.gnome.desktop.interface gtk-theme 'Adwaita'
gset org.gnome.desktop.interface cursor-theme 'Black-Minimalistic'
gset org.gnome.desktop.interface icon-theme 'Papirus'

# Mouse & Touchpad Settings
gset org.gnome.desktop.input-sources xkb-options "['caps:backspace']"
gset org.gnome.desktop.peripherals.mouse speed '0.1'
gset org.gnome.desktop.peripherals.mouse accel-profile 'flat'
gset org.gnome.desktop.peripherals.touchpad accel-profile 'flat'
gset org.gnome.desktop.peripherals.touchpad speed '0.1'
gset org.gnome.desktop.peripherals.touchpad tap-to-click 'true'
gset org.gnome.desktop.peripherals.touchpad natural-scroll 'true'
gset org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled 'true'
gset org.gnome.desktop.peripherals.touchpad click-method 'fingers'

# Focus Follows Mouse Instant
gset org.gnome.mutter focus-change-on-pointer-rest false
ext_gset pop-shell@system76.com org.gnome.shell.extensions.pop-shell mouse-cursor-focus-location 'uint32 0'
ext_gset pop-shell@system76.com org.gnome.shell.extensions.pop-shell mouse-cursor-follows-active-window true
gset org.gnome.desktop.wm.preferences auto-raise-delay '200'
dconf write /org/gnome/desktop/wm/preferences/focus-mode "'mouse'"
dconf write /org/gnome/desktop/wm/preferences/auto-raise "false"

# Fonts
gset org.gnome.desktop.interface font-name 'FiraCode Nerd Font Medium 10'
gset org.gnome.desktop.interface document-font-name 'FiraCode Nerd Font 10'
gset org.gnome.desktop.interface monospace-font-name 'FiraCode Nerd Font Mono Light 10'
gset org.gnome.desktop.wm.preferences titlebar-font 'Adwaita Sans Bold 11'

# Night Light
gset org.gnome.settings-daemon.plugins.color night-light-enabled 'true'
gset org.gnome.settings-daemon.plugins.color night-light-schedule-automatic 'false'
gset org.gnome.settings-daemon.plugins.color night-light-schedule-from '20'
gset org.gnome.settings-daemon.plugins.color night-light-schedule-to '04'
gset org.gnome.settings-daemon.plugins.color night-light-temperature '2300'

# Gnome Shell Icon List
gset org.gnome.shell favorite-apps "['net.waterfox.waterfox.desktop', 'waterfox.desktop', 'org.gnome.Nautilus.desktop', 'org.libreoffice.LibreOffice.writer.desktop', 'org.gnome.Calculator.desktop', 'md.obsidian.Obsidian.desktop', 'com.visualstudio.code.desktop', 'code.desktop', 'synochat.desktop']"


##################
### Extensions ###
##################

# Pop Shell
if ext_installed pop-shell@system76.com; then
    ext_gset pop-shell@system76.com org.gnome.shell.extensions.pop-shell toggle-floating "['<Shift><Super>f']"
    dconf write /org/gnome/shell/extensions/pop-shell/hint-color-rgba "'rgb(255,255,255)'"
    ext_gset pop-shell@system76.com org.gnome.shell.extensions.pop-shell stacking-with-mouse false
    ext_gset pop-shell@system76.com org.gnome.shell.extensions.pop-shell active-hint-border-radius 'uint32 7'
    ext_gset pop-shell@system76.com org.gnome.shell.extensions.pop-shell gap-inner 'uint32 4'
    ext_gset pop-shell@system76.com org.gnome.shell.extensions.pop-shell gap-outer 'uint32 6'
    ext_gset pop-shell@system76.com org.gnome.shell.extensions.pop-shell tile-orientation "['<Super>x']"
    ext_gset pop-shell@system76.com org.gnome.shell.extensions.pop-shell active-hint true
    ext_gset pop-shell@system76.com org.gnome.shell.extensions.pop-shell tile-by-default true
fi

# Pop!_OS COSMIC dock bits (Pop!_OS only)
if ext_installed pop-cosmic@system76.com; then
    dconf write /org/gnome/shell/extensions/pop-cosmic/show-workspaces-button 'false'
    dconf write /org/gnome/shell/extensions/pop-cosmic/show-applications-button 'false'
fi

# Super Key
if ext_installed super-key@tommimon.github.com; then
    dconf write /org/gnome/shell/extensions/super-key/overlay/key/action "'ulauncher'"
    ext_gset super-key@tommimon.github.com org.gnome.shell.extensions.super-key overlay-key 'ulauncher'
fi

# Useless Gaps
if ext_installed useless-gaps@pimsnel.com; then
    dconf write /org/gnome/shell/extensions/useless-gaps/gap-size "20"
fi

# Just Perfection
if ext_installed just-perfection-desktop@just-perfection; then
    dconf write /org/gnome/shell/extensions/just-perfection/dash-icon-size "48"
    dconf write /org/gnome/shell/extensions/just-perfection/animation "3"
    dconf write /org/gnome/shell/extensions/just-perfection/startup-status "0"
    dconf write /org/gnome/shell/extensions/just-perfection/app-menu-icon "false"
    dconf write /org/gnome/shell/extensions/just-perfection/activities-button "false"
    dconf write /org/gnome/shell/extensions/just-perfection/app-menu "false"
    dconf write /org/gnome/shell/extensions/just-perfection/app-menu-label "false"
    dconf write /org/gnome/shell/extensions/just-perfection/search "false"
    dconf write /org/gnome/shell/extensions/just-perfection/theme "true"
fi

# Caffeine
if ext_installed caffeine@patapon.info; then
    dconf write /org/gnome/shell/extensions/caffeine/duration-timer "4"
fi

# Awesome Tiles
if ext_installed awesome-tiles@velitasali.com; then
    dconf write /org/gnome/shell/extensions/awesome-tiles/gap-size-increments "1"
fi

# AZ Taskbar
if ext_installed aztaskbar@aztaskbar.gitlab.com; then
    dconf write /org/gnome/shell/extensions/aztaskbar/favorites "false"
    dconf write /org/gnome/shell/extensions/aztaskbar/main-panel-height "33"
    dconf write /org/gnome/shell/extensions/aztaskbar/panel-on-all-monitors "false"
    dconf write /org/gnome/shell/extensions/aztaskbar/show-panel-activities-button "false"
    dconf write /org/gnome/shell/extensions/aztaskbar/icon-size "23"
    dconf write /org/gnome/shell/extensions/aztaskbar/hide-dash "false"
    dconf write /org/gnome/shell/extensions/aztaskbar/indicator-color-focused "'rgb(246,148,255)'"
    dconf write /org/gnome/shell/extensions/aztaskbar/indicator-color-running "'rgb(130,226,255)'"
fi

# Blur My Shell
if ext_installed blur-my-shell@aunetx; then
    dconf write /org/gnome/shell/extensions/blur-my-shell/brightness "1.0"
fi

# Space Bar
if ext_installed space-bar@luchrioh; then
    dconf write /org/gnome/shell/extensions/space-bar/behavior/show-empty-workspaces 'false'
    dconf write /org/gnome/shell/extensions/space-bar/behavior/toggle-overview 'false'
    dconf write /org/gnome/shell/extensions/space-bar/shortcuts/enable-move-to-workspace-shortcuts 'true'
fi

# Forge
if ext_installed forge@jmmaranan.com; then
    dconf write /org/gnome/shell/extensions/forge/stacked-tiling-mode-enabled 'false'
    dconf write /org/gnome/shell/extensions/forge/tabbed-tiling-mode-enabled 'false'
    dconf write /org/gnome/shell/extensions/forge/preview-hint-enabled 'false'
    dconf write /org/gnome/shell/extensions/forge/window-gap-size 'uint32 7'
    dconf write /org/gnome/shell/extensions/forge/move-pointer-focus-enabled 'true'
fi

# Workspace buttons with App Icons
if ext_installed workspace-buttons-with-app-icons@miro011.github.com; then
    dconf write /org/gnome/shell/extensions/workspace-buttons-with-app-icons/top-bar-height "27"
    dconf write /org/gnome/shell/extensions/workspace-buttons-with-app-icons/wsb-ws-num-font-size "16"
    dconf write /org/gnome/shell/extensions/workspace-buttons-with-app-icons/wsb-ws-num-active-color "'rgba(255, 255, 255, 0.39)'"
    dconf write /org/gnome/shell/extensions/workspace-buttons-with-app-icons/wsb-ws-app-icons-wrapper-active-color "'rgba(255, 255, 255, 0.39)'"
    dconf write /org/gnome/shell/extensions/workspace-buttons-with-app-icons/wsb-ws-btn-border-active-color "'rgba(255, 255, 255, 1)'"
fi

# Nautilus Open Any Terminal (nautilus-python extension, global schema)
gset com.github.stunkymonkey.nautilus-open-any-terminal terminal 'kitty'
gset com.github.stunkymonkey.nautilus-open-any-terminal new-tab true
gset com.github.stunkymonkey.nautilus-open-any-terminal flatpak 'system'

# Disable distro defaults that fight the rice (Pop!_OS / Ubuntu / Fedora)
for ext in \
    'cosmic-dock@system76.com' \
    'cosmic-workspaces@system76.com' \
    'popx11gestures@system76.com' \
    'pop-cosmic@system76.com' \
    'ding@rastersoft.com' \
    'apps-menu@gnome-shell-extensions.gcampax.github.com' \
    'background-logo@fedorahosted.org' \
    'tiling-assistant@ubuntu.com' \
    'ubuntu-dock@ubuntu.com'
do
    ext_disable "$ext"
done

# Enable the rice's extensions (installed ones only).
# New installs only take effect after the shell restarts; re-run after login.
for ext in \
    'ubuntu-appindicators@ubuntu.com' \
    'appindicatorsupport@rgcjonas.gmail.com' \
    'gsconnect@andyholmes.github.io' \
    'aztaskbar@aztaskbar.gitlab.com' \
    'blur-my-shell@aunetx' \
    'caffeine@patapon.info' \
    'just-perfection-desktop@just-perfection' \
    'forge@jmmaranan.com' \
    'pop-shell@system76.com' \
    'useless-gaps@pimsnel.com' \
    'system76-power@system76.com' \
    'awesome-tiles@velitasali.com' \
    'workspace-buttons-with-app-icons@miro011.github.com' \
    'super-key@tommimon.github.com'
do
    ext_enable "$ext"
done

echo -e "${BLUE}PiercingXX's Rice Applied!${NC}"
