#!/usr/bin/env bash
# Skippy desk seat — waybar module + Hyprland autostart.
# Not launch-skippy-remote.sh (that SSHs to skippy-debian-5090).

desk_bin() {
    if [ -n "${SKIPPY_REMOTE:-}" ] && [ -x "${SKIPPY_REMOTE}" ]; then
        printf '%s\n' "$SKIPPY_REMOTE"
        return 0
    fi
    if [ -x "${HOME}/.local/bin/skippy-remote" ]; then
        printf '%s\n' "${HOME}/.local/bin/skippy-remote"
        return 0
    fi
    command -v skippy-remote 2>/dev/null || true
}

running() {
    pgrep -f '/share/skippy-remote/skippy-remote.py' >/dev/null 2>&1
}

cmd="${1:-status}"
bin="$(desk_bin)"

case "$cmd" in
    status)
        [ -n "$bin" ] || exit 0
        class=stopped
        tooltip="Skippy — click to open"
        if running; then
            class=running
            tooltip="Skippy — click to show, right-click to quit"
        fi
        printf '{"text":">","alt":"%s","class":"%s","tooltip":"%s"}\n' \
            "$class" "$class" "$tooltip"
        ;;
    show)
        [ -n "$bin" ] || exit 0
        exec "$bin" --show
        ;;
    autostart)
        [ -n "$bin" ] || exit 0
        sleep 2
        exec "$bin"
        ;;
    quit)
        pkill -f '/share/skippy-remote/skippy-remote.py' >/dev/null 2>&1 || true
        ;;
    *)
        echo "usage: $0 {status|show|autostart|quit}" >&2
        exit 2
        ;;
esac
