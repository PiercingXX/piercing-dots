#!/bin/bash
# GitHub.com/PiercingXX
# Toggle the top bar (waybar on Wayland, polybar or waybar on X11).
# --startup restores the last on/off state at login.

set -e

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_FILE="$STATE_DIR/topbar/state"

mkdir -p "$STATE_DIR/topbar"

session_kind() {
    if [ -n "${WAYLAND_DISPLAY:-}" ] || [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
        echo "wayland"
        return
    fi

    echo "x11"
}

read_state() {
    if [ -f "$STATE_FILE" ]; then
        # shellcheck disable=SC1090
        . "$STATE_FILE"
    fi
    LAST_ENABLED="${LAST_ENABLED:-on}"
    LAST_BAR="${LAST_BAR:-}"
    LAST_BAR_WAYLAND="${LAST_BAR_WAYLAND:-}"
    LAST_BAR_X11="${LAST_BAR_X11:-}"
}

write_state() {
    local enabled="$1"
    local bar="$2"
    local kind

    kind="$(session_kind)"

    if [ "$kind" = "wayland" ]; then
        LAST_BAR_WAYLAND="$bar"
    else
        LAST_BAR_X11="$bar"
    fi

    cat > "$STATE_FILE" <<EOF
LAST_ENABLED=$enabled
LAST_BAR=$bar
LAST_BAR_WAYLAND=$LAST_BAR_WAYLAND
LAST_BAR_X11=$LAST_BAR_X11
EOF
}

start_bar() {
    local target="$1"

    if [ "$target" = "waybar" ] && command -v waybar >/dev/null 2>&1; then
        setsid -f waybar >"$STATE_DIR/topbar/waybar.log" 2>&1
        write_state on waybar
        return 0
    fi

    # polybar is X11-only
    if [ "$target" = "polybar" ] && [ "$(session_kind)" = "x11" ] && command -v polybar >/dev/null 2>&1; then
        local log="$STATE_DIR/topbar/polybar.log"
        if command -v launchpolybar >/dev/null 2>&1; then
            setsid -f launchpolybar >"$log" 2>&1
        elif [ -f "$HOME/.config/herbstluftwm/polybar.ini" ]; then
            setsid -f polybar -q main -c "$HOME/.config/herbstluftwm/polybar.ini" >"$log" 2>&1
        else
            setsid -f polybar main >"$log" 2>&1
        fi
        write_state on polybar
        return 0
    fi

    return 1
}

default_bar() {
    local kind="$1"

    if [ "$kind" = "wayland" ]; then
        if command -v waybar >/dev/null 2>&1; then
            echo "waybar"
            return
        fi
        echo ""
        return
    fi

    if command -v polybar >/dev/null 2>&1; then
        echo "polybar"
        return
    fi
    if command -v waybar >/dev/null 2>&1; then
        echo "waybar"
        return
    fi
    echo ""
}

preferred_bar() {
    local kind
    kind="$(session_kind)"

    if [ "$kind" = "wayland" ] && [ "$LAST_BAR_WAYLAND" = "waybar" ]; then
        echo "$LAST_BAR_WAYLAND"
        return
    fi

    if [ "$kind" = "x11" ] && [ -n "$LAST_BAR_X11" ]; then
        echo "$LAST_BAR_X11"
        return
    fi

    if [ -n "$LAST_BAR" ] && { [ "$kind" = "x11" ] || [ "$LAST_BAR" != "polybar" ]; }; then
        echo "$LAST_BAR"
        return
    fi

    default_bar "$kind"
}

stop_running_bar() {
    if pgrep -x waybar >/dev/null 2>&1; then
        pkill -x waybar
        write_state off waybar
        return 0
    fi

    if pgrep -x polybar >/dev/null 2>&1; then
        pkill -x polybar
        write_state off polybar
        return 0
    fi

    return 1
}

running_bar() {
    if pgrep -x waybar >/dev/null 2>&1; then
        echo "waybar"
        return 0
    fi

    if pgrep -x polybar >/dev/null 2>&1; then
        echo "polybar"
        return 0
    fi

    return 1
}

startup_mode=false
if [ "${1:-}" = "--startup" ]; then
    startup_mode=true
fi

read_state

current_bar="$(running_bar || true)"

if [ "$startup_mode" = true ] && [ -n "$current_bar" ]; then
    write_state on "$current_bar"
    exit 0
fi

if [ "$startup_mode" = false ] && [ -n "$current_bar" ]; then
    stop_running_bar
    exit 0
fi

if [ "$startup_mode" = true ] && [ "$LAST_ENABLED" = "off" ]; then
    exit 0
fi

target_bar="$(preferred_bar)"

if [ -n "$target_bar" ] && start_bar "$target_bar"; then
    exit 0
fi

fallback_bar="$(default_bar "$(session_kind)")"
[ -n "$fallback_bar" ] && start_bar "$fallback_bar" || true
