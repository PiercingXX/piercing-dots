#!/bin/bash
# GitHub.com/PiercingXX
# Workspace switch notification daemon for every WM in the rice.
# Shows the current workspace and all occupied ones, e.g. "Open: 1 [2] 4".
#   Hyprland      event socket (socket2)
#   Sway / i3     swaymsg / i3-msg subscribe
#   herbstluftwm  herbstclient --idle
#   awesome       one-shot (rc.lua calls it on tag change): --once
# Usage: workspace-notify.sh [--wm NAME] [--once]

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

QUICK_TIMEOUT=1100
WM=""
ONCE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --wm)   WM="${2:-}"; shift ;;
        --wm=*) WM="${1#--wm=}" ;;
        --once) ONCE=1 ;;
    esac
    shift
done
[ -n "$WM" ] || WM=$(detect_wm)

notify_ws() {
    notify_replace workspace low "$QUICK_TIMEOUT" "" "Workspace $1" "${2:+Open: $2}"
}

# "1 2 4" + current 2 -> "1 [2] 4" (current added if it has no windows)
format_list() {
    local current="$1"; shift
    local ws parts=()
    while IFS= read -r ws; do
        [ -n "$ws" ] || continue
        if [[ "$ws" == "$current" ]]; then parts+=("[$ws]"); else parts+=("$ws"); fi
    done < <(printf '%s\n' "$current" "$@" | sort -uV)
    printf '%s' "${parts[*]}"
}

swaync_follow() {
    [ -n "$1" ] && command_exists swaync-client || return 0
    swaync-client --change-noti-monitor "$1" -sw >/dev/null 2>&1 || true
    swaync-client --change-cc-monitor "$1" -sw >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# Hyprland
# ---------------------------------------------------------------------------
hypr_notify() {
    local current="$1" occupied
    if [ -z "$current" ]; then
        current=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id') || return 0
    fi
    mapfile -t occupied < <(hyprctl workspaces -j 2>/dev/null \
        | jq -r '[.[] | select(.windows > 0 and .id > 0) | .id] | sort | .[]')
    notify_ws "$current" "$(format_list "$current" "${occupied[@]}")"
}

hypr_stream() {
    local socket="$1"
    if command_exists socat; then
        socat -U - "UNIX-CONNECT:${socket}" 2>/dev/null
    elif command_exists nc && nc -h 2>&1 | grep -q -- '-U'; then
        nc -U "${socket}" 2>/dev/null
    elif command_exists python3; then
        python3 - "${socket}" 2>/dev/null <<'PYEOF'
import socket as _s, sys
s = _s.socket(_s.AF_UNIX, _s.SOCK_STREAM)
s.connect(sys.argv[1])
while True:
    data = s.recv(4096)
    if not data: break
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()
PYEOF
    else
        echo "workspace-notify: need socat, nc (-U), or python3 for Hyprland IPC." >&2
        return 1
    fi
}

run_hyprland() {
    command_exists hyprctl && command_exists jq || { echo "workspace-notify: need hyprctl and jq." >&2; exit 1; }
    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        echo "workspace-notify: HYPRLAND_INSTANCE_SIGNATURE not set." >&2
        exit 1
    fi
    if [ "$ONCE" -eq 1 ]; then hypr_notify ""; return; fi

    local socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
    swaync_follow "$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' | head -n1)"

    local line event data
    hypr_stream "$socket" | while IFS= read -r line; do
        event="${line%%>>*}"
        data="${line#*>>}"
        case "$event" in
            workspacev2)                       # ID,NAME
                hypr_notify "${data%%,*}" ;;
            focusedmonv2)                      # MONNAME,WORKSPACEID
                swaync_follow "${data%%,*}"
                hypr_notify "${data##*,}" ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Sway / i3 (same IPC protocol)
# ---------------------------------------------------------------------------
sway_notify() {
    local msg="$1" current occupied
    current=$($msg -t get_workspaces -r 2>/dev/null | jq -r '.[] | select(.focused==true) | .name' | head -n1)
    [[ -n "$current" && "$current" != "null" ]] || return 0
    mapfile -t occupied < <($msg -t get_tree -r 2>/dev/null \
        | jq -r '.. | objects
            | select(.type? == "workspace")
            | select((((.nodes // []) | length) + ((.floating_nodes // []) | length)) > 0)
            | .name' \
        | awk 'NF && !/^__/' | sort -u)
    notify_ws "$current" "$(format_list "$current" "${occupied[@]}")"
}

run_sway_like() {
    local msg="$1"
    command_exists "$msg" && command_exists jq || exit 0
    sway_notify "$msg"
    [ "$ONCE" -eq 1 ] && return
    $msg -t subscribe -m '["workspace","output"]' 2>/dev/null | while IFS= read -r _; do
        if [ "$msg" = swaymsg ]; then
            swaync_follow "$(swaymsg -t get_outputs -r 2>/dev/null | jq -r '.[] | select(.focused==true) | .name' | head -n1)"
        fi
        sway_notify "$msg"
    done
}

# ---------------------------------------------------------------------------
# herbstluftwm
# ---------------------------------------------------------------------------
herbst_notify() {
    local current tag prefix occupied=()
    current=$(herbstclient attr tags.focus.name 2>/dev/null) || return 0
    [ -n "$current" ] || return 0
    for tag in $(herbstclient tag_status 2>/dev/null); do
        prefix="${tag:0:1}"
        case "$prefix" in
            '#'|':'|'+'|'-'|'%') occupied+=("${tag:1}") ;;
        esac
    done
    notify_ws "$current" "$(format_list "$current" "${occupied[@]}")"
}

run_herbst() {
    command_exists herbstclient || exit 0
    herbst_notify
    [ "$ONCE" -eq 1 ] && return
    herbstclient --idle 'focus_changed|tag_changed' 2>/dev/null | while IFS= read -r _; do
        herbst_notify
    done
}

# ---------------------------------------------------------------------------
# awesome (no event stream outside lua; rc.lua calls us with --once)
# ---------------------------------------------------------------------------
run_awesome() {
    command_exists awesome-client || exit 0
    local current
    current=$(awesome-client 'local awful=require("awful"); local s=awful.screen.focused(); local t=s and s.selected_tag; if t and t.name then return t.name end' 2>/dev/null \
        | sed -n 's/^[[:space:]]*string "\(.*\)"$/\1/p')
    [ -n "$current" ] || return 0
    notify_ws "$current" ""
}

case "$WM" in
    hyprland) [ "$ONCE" -eq 1 ] || single_instance workspace-notify || exit 0; run_hyprland ;;
    sway)     [ "$ONCE" -eq 1 ] || single_instance workspace-notify || exit 0; run_sway_like swaymsg ;;
    i3)       [ "$ONCE" -eq 1 ] || single_instance workspace-notify || exit 0; run_sway_like i3-msg ;;
    herbstluftwm) [ "$ONCE" -eq 1 ] || single_instance workspace-notify || exit 0; run_herbst ;;
    awesome)  run_awesome ;;
    *)        exit 0 ;;  # qtile/dwm/bspwm: no supported event source
esac
