# shellcheck shell=bash
# GitHub.com/PiercingXX
# Shared helpers for ~/.scripts. Source this file, do not execute it:
#   . "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"
# Distro detection mirrors linux-mod's lib/pkg.sh so both agree on DISTRO.

[ -n "${PX_COMMON_LOADED:-}" ] && return 0
PX_COMMON_LOADED=1

# ---------------------------------------------------------------------------
# Colors (upper and lower case names; older scripts use both)
# ---------------------------------------------------------------------------
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'
if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
    RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi
red="$RED"; green="$GREEN"; yellow="$YELLOW"; blue="$BLUE"; nc="$NC"

say()  { printf '%s\n' "${YELLOW}$*${NC}"; }
ok()   { printf '%s\n' "${GREEN}$*${NC}"; }
warn() { printf '%s\n' "${YELLOW}$*${NC}" >&2; }
err()  { printf '%s\n' "${RED}$*${NC}" >&2; }
die()  { err "$*"; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# Per-user state/log dir and the external storage root (override via env)
PX_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/piercingxx"
PX_WORK_ROOT="${PIERCINGXX_WORK_ROOT:-/media/Working-Storage}"
PX_ARCHIVE_ROOT="${PIERCINGXX_ARCHIVE_ROOT:-/media/Archived-Storage}"

refuse_root() {
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        die "Run this as your normal user, not root. It will ask for sudo when needed."
    fi
}

# ---------------------------------------------------------------------------
# Distro / init detection
#   DISTRO     arch|artix|debian|fedora|void|suse|alpine|unknown
#   DISTRO_ID  raw ID from os-release (cachyos, ubuntu, postmarketos, ...)
#   PKG        pacman|apt|dnf|xbps|zypper|apk|""
#   INIT       systemd|runit|openrc|dinit|s6|unknown
# os-release is read in a subshell so NAME/VERSION/etc. don't leak in.
# ---------------------------------------------------------------------------
detect_distro() {
    local id="" id_like=""
    if [ -r /etc/os-release ]; then
        id=$(. /etc/os-release && printf '%s' "${ID:-}")
        id_like=$(. /etc/os-release && printf '%s' "${ID_LIKE:-}")
    fi
    DISTRO_ID="$id"

    case "$id" in
        artix)                                       DISTRO="artix" ;;
        arch|cachyos|endeavouros|manjaro|garuda)     DISTRO="arch" ;;
        debian|ubuntu|pop|linuxmint|mint|mobian|furios|droidian|ubuntu-touch) DISTRO="debian" ;;
        fedora|bazzite|rhel|centos)                  DISTRO="fedora" ;;
        void)                                        DISTRO="void" ;;
        opensuse*|sles|suse)                         DISTRO="suse" ;;
        alpine|postmarketos)                         DISTRO="alpine" ;;
        *)
            case " $id_like " in
                *artix*)           DISTRO="artix" ;;
                *arch*)            DISTRO="arch" ;;
                *debian*|*ubuntu*) DISTRO="debian" ;;
                *fedora*|*rhel*)   DISTRO="fedora" ;;
                *suse*)            DISTRO="suse" ;;
                *alpine*)          DISTRO="alpine" ;;
                *)                 DISTRO="unknown" ;;
            esac ;;
    esac

    case "$DISTRO" in
        arch|artix) PKG="pacman" ;;
        debian)     PKG="apt" ;;
        fedora)     PKG="dnf" ;;
        void)       PKG="xbps" ;;
        suse)       PKG="zypper" ;;
        alpine)     PKG="apk" ;;
        *)          PKG="" ;;
    esac

    if [ -d /run/systemd/system ]; then
        INIT="systemd"
    elif command_exists sv && { [ -d /etc/runit ] || [ -d /var/service ]; }; then
        INIT="runit"
    elif command_exists rc-service; then
        INIT="openrc"
    elif command_exists dinitctl; then
        INIT="dinit"
    elif command_exists s6-rc; then
        INIT="s6"
    else
        INIT="unknown"
    fi
}

is_arch_like() { [ "${DISTRO:-}" = arch ] || [ "${DISTRO:-}" = artix ]; }

# First available AUR helper (paru preferred), empty if none
aur_helper() {
    if command_exists paru; then echo paru
    elif command_exists yay; then echo yay
    fi
}

# pkg_install pkg... : install from the distro repos, skipping what's present.
# Never uses `pacman -Sy <pkg>` (partial upgrade); a stale db fails loudly instead.
pkg_install() {
    [ $# -gt 0 ] || return 0
    [ -n "${PKG:-}" ] || detect_distro
    case "$PKG" in
        pacman) sudo pacman -S --needed --noconfirm "$@" ;;
        apt)    sudo apt-get install -y "$@" ;;
        dnf)    sudo dnf install -y "$@" ;;
        xbps)   sudo xbps-install -y "$@" ;;
        zypper) sudo zypper -n install "$@" ;;
        apk)    sudo apk add "$@" ;;
        *)      err "No supported package manager found."; return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# Services (init-aware; Artix/Void/Alpine have no systemd)
# ---------------------------------------------------------------------------
svc_is_active() {
    [ -n "${INIT:-}" ] || detect_distro
    case "$INIT" in
        systemd) systemctl is-active --quiet "$1" ;;
        runit)   sv status "$1" 2>/dev/null | grep -q '^run:' ;;
        openrc)  rc-service "$1" status >/dev/null 2>&1 ;;
        dinit)   dinitctl status "$1" 2>/dev/null | grep -qi 'started' ;;
        s6)      s6-svstat "/run/service/$1" 2>/dev/null | grep -q '^up' ;;
        *)       pgrep -x "$1" >/dev/null 2>&1 ;;
    esac
}

svc_exists() {
    [ -n "${INIT:-}" ] || detect_distro
    case "$INIT" in
        systemd) systemctl list-unit-files "$1.service" "$1.socket" "$1" 2>/dev/null | grep -q "^$1" ;;
        runit)   [ -d "/etc/sv/$1" ] || [ -d "/etc/runit/sv/$1" ] ;;
        openrc)  [ -x "/etc/init.d/$1" ] ;;
        dinit)   [ -f "/etc/dinit.d/$1" ] ;;
        s6)      [ -d "/etc/s6/sv/$1" ] ;;
        *)       return 1 ;;
    esac
}

svc_start() {
    [ -n "${INIT:-}" ] || detect_distro
    case "$INIT" in
        systemd) sudo systemctl start "$1" ;;
        runit)   sudo sv up "$1" ;;
        openrc)  sudo rc-service "$1" start ;;
        dinit)   sudo dinitctl start "$1" ;;
        s6)      sudo s6-rc -u change "$1" ;;
        *)       return 1 ;;
    esac
}

svc_stop() {
    [ -n "${INIT:-}" ] || detect_distro
    case "$INIT" in
        systemd) sudo systemctl stop "$1" ;;
        runit)   sudo sv down "$1" ;;
        openrc)  sudo rc-service "$1" stop ;;
        dinit)   sudo dinitctl stop "$1" ;;
        s6)      sudo s6-rc -d change "$1" ;;
        *)       return 1 ;;
    esac
}

svc_enable_now() {
    [ -n "${INIT:-}" ] || detect_distro
    case "$INIT" in
        systemd) sudo systemctl enable --now "$1" ;;
        runit)
            local d=/etc/sv/$1
            [ -d "$d" ] || d=/etc/runit/sv/$1
            local svdir=/var/service
            [ -d /run/runit/service ] && svdir=/run/runit/service
            sudo ln -sf "$d" "$svdir/" ;;
        openrc)  sudo rc-update add "$1" default && sudo rc-service "$1" start ;;
        dinit)   sudo dinitctl enable "$1" ;;
        s6)      sudo s6-service add default "$1" && sudo s6-rc -u change "$1" ;;
        *)       return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# Interaction (gum when present, plain read otherwise)
# ---------------------------------------------------------------------------
pause() {
    local msg="${1:-Press Enter to continue...}"
    [ -t 0 ] || return 0
    read -r -p "$msg" _
}

# confirm "Question?" -> 0 yes / 1 no. PX_ASSUME_YES=1 answers yes.
confirm() {
    [ "${PX_ASSUME_YES:-0}" = 1 ] && return 0
    [ -t 0 ] || return 1
    if command_exists gum; then
        gum confirm "$1"
    else
        local a
        read -r -p "$1 [y/N] " a
        [[ "$a" =~ ^[Yy]$ ]]
    fi
}

# ---------------------------------------------------------------------------
# Single instance lock for long-running daemons.
#   single_instance battery-notify || exit 0
# Holds fd 9 for the life of the process.
# ---------------------------------------------------------------------------
single_instance() {
    local dir="${XDG_RUNTIME_DIR:-/tmp}"
    local lock="$dir/piercingxx-$1.lock"
    exec 9>"$lock" || return 1
    flock -n 9
}

# ---------------------------------------------------------------------------
# Notifications
#   notify_replace KEY URGENCY TIMEOUT_MS ICON SUMMARY [BODY]
# KEY is a short name ("volume", "battery"); the same key replaces the
# previous bubble on swaync (replace-id + synchronous hint) and dunst (stack tag).
# ---------------------------------------------------------------------------
_px_notify_id() {
    # Stable numeric id per key so -r replaces across processes
    local sum
    sum=$(printf '%s' "$1" | cksum | cut -d' ' -f1)
    echo $(( 90000 + sum % 9000 ))
}

notify_replace() {
    local key="$1" urgency="$2" timeout="$3" icon="$4" summary="$5" body="${6:-}"
    command_exists notify-send || return 0
    local id
    id=$(_px_notify_id "$key")
    notify-send -r "$id" -u "$urgency" -t "$timeout" -i "$icon" \
        -h "string:x-canonical-private-synchronous:$key" \
        -h "string:x-dunst-stack-tag:$key" \
        "$summary" "$body" 2>/dev/null \
    || notify-send -u "$urgency" -t "$timeout" -i "$icon" \
        -h "string:x-canonical-private-synchronous:$key" \
        "$summary" "$body" 2>/dev/null || true
}

# osd ICON SUMMARY VALUE(0-100) : one shared on-screen-display slot for
# volume, brightness and mic so they replace each other instead of stacking.
osd() {
    local icon="$1" summary="$2" value="$3"
    command_exists notify-send || return 0
    local id
    id=$(_px_notify_id osd)
    notify-send -r "$id" -u low -t 1500 -i "$icon" \
        -h "int:value:$value" \
        -h "string:x-canonical-private-synchronous:osd" \
        -h "string:x-dunst-stack-tag:osd" \
        "$summary" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Session / window manager detection
#   detect_wm -> hyprland|sway|niri|river|i3|bspwm|herbstluftwm|awesome|qtile|dwm|gnome|kde|wayland|x11|tty
# ---------------------------------------------------------------------------
detect_wm() {
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then echo hyprland; return; fi
    if [ -n "${SWAYSOCK:-}" ]; then echo sway; return; fi
    if [ -n "${NIRI_SOCKET:-}" ]; then echo niri; return; fi
    if [ -n "${I3SOCK:-}" ] || { [ -n "${DISPLAY:-}" ] && pgrep -x i3 >/dev/null 2>&1; }; then echo i3; return; fi
    local desk="${XDG_CURRENT_DESKTOP:-${XDG_SESSION_DESKTOP:-${DESKTOP_SESSION:-}}}"
    desk=$(printf '%s' "$desk" | tr '[:upper:]' '[:lower:]')
    case "$desk" in
        *hyprland*) echo hyprland; return ;;
        *sway*)     echo sway; return ;;
        *gnome*)    echo gnome; return ;;
        *kde*|*plasma*) echo kde; return ;;
        *river*)    echo river; return ;;
        *qtile*)    echo qtile; return ;;
        *awesome*)  echo awesome; return ;;
        *bspwm*)    echo bspwm; return ;;
        *herbst*)   echo herbstluftwm; return ;;
        *dwm*)      echo dwm; return ;;
        *i3*)       echo i3; return ;;
    esac
    local wm
    for wm in bspwm herbstluftwm awesome qtile dwm; do
        pgrep -x "$wm" >/dev/null 2>&1 && { echo "$wm"; return; }
    done
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then echo wayland
    elif [ -n "${DISPLAY:-}" ]; then echo x11
    else echo tty
    fi
}

is_wayland() { [ -n "${WAYLAND_DISPLAY:-}" ]; }

# clip_copy : stdin -> clipboard for the current session type
clip_copy() {
    if is_wayland && command_exists wl-copy; then
        wl-copy
    elif command_exists xclip; then
        xclip -selection clipboard
    elif command_exists xsel; then
        xsel --clipboard --input
    elif command_exists wl-copy; then
        wl-copy
    else
        return 1
    fi
}

# menu_select "Prompt" : stdin lines -> chosen line (fuzzel/wofi/rofi/dmenu)
menu_select() {
    local prompt="${1:-Select}"
    if is_wayland && command_exists fuzzel; then
        fuzzel --dmenu --prompt "$prompt: "
    elif is_wayland && command_exists wofi; then
        wofi --dmenu --prompt "$prompt"
    elif command_exists rofi; then
        rofi -dmenu -i -p "$prompt"
    elif command_exists dmenu; then
        dmenu -i -p "$prompt"
    elif command_exists fuzzel; then
        fuzzel --dmenu --prompt "$prompt: "
    else
        return 1
    fi
}
