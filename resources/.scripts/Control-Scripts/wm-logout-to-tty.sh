#!/usr/bin/env bash
set -euo pipefail

# Log out from the current desktop/session and return to a text TTY.
# Usage: wm-logout-to-tty.sh [tty_number]
# Example: wm-logout-to-tty.sh 1

log() {
    printf '[wm-logout] %s\n' "$*" >&2
}

warn() {
    printf '[wm-logout] warning: %s\n' "$*" >&2
}

die() {
    printf '[wm-logout] error: %s\n' "$*" >&2
    exit 1
}

target_vt="${1:-1}"

if [[ ! "$target_vt" =~ ^[0-9]+$ ]]; then
    die "TTY must be a number (got: $target_vt)."
fi

find_user_tty_session() {
    local sid name type class tty
    while read -r sid _; do
        [[ -n "$sid" ]] || continue
        name="$(loginctl show-session "$sid" -p Name --value 2>/dev/null || true)"
        type="$(loginctl show-session "$sid" -p Type --value 2>/dev/null || true)"
        class="$(loginctl show-session "$sid" -p Class --value 2>/dev/null || true)"
        tty="$(loginctl show-session "$sid" -p TTY --value 2>/dev/null || true)"

        if [[ "$name" == "$USER" ]] && [[ "$type" == "tty" ]] && [[ "$class" == "user" ]] && [[ "$tty" == "tty$target_vt" ]]; then
            printf '%s\n' "$sid"
            return 0
        fi
    done < <(loginctl list-sessions --no-legend 2>/dev/null)

    return 1
}

switch_to_target_tty() {
    local tty_session

    if tty_session="$(find_user_tty_session || true)" && [[ -n "$tty_session" ]]; then
        if loginctl activate "$tty_session" >/dev/null 2>&1; then
            log "Activated existing user TTY session tty$target_vt (session $tty_session)."
            return 0
        fi
        warn "Could not activate tty$target_vt session with loginctl."
    fi

    if command -v chvt >/dev/null 2>&1; then
        if chvt "$target_vt" >/dev/null 2>&1; then
            log "Switched VT to tty$target_vt via chvt."
            return 0
        fi
        warn "chvt failed (may require elevated privileges on your setup)."
    else
        warn "chvt not found; cannot force VT switch directly."
    fi

    return 1
}

logout_current_session() {
    # Hyprland
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
        log "Logging out via hyprctl dispatch exit."
        exec hyprctl dispatch exit
    fi

    # Sway
    if [[ -n "${SWAYSOCK:-}" ]] && command -v swaymsg >/dev/null 2>&1; then
        log "Logging out via swaymsg exit."
        exec swaymsg exit
    fi

    # i3
    if [[ -n "${I3SOCK:-}" ]] && command -v i3-msg >/dev/null 2>&1; then
        log "Logging out via i3-msg exit."
        exec i3-msg exit
    fi

    # GNOME
    if [[ "${XDG_CURRENT_DESKTOP:-}" == *"GNOME"* ]] && command -v gnome-session-quit >/dev/null 2>&1; then
        log "Logging out via gnome-session-quit."
        exec gnome-session-quit --logout --no-prompt
    fi

    # XFCE
    if [[ "${XDG_CURRENT_DESKTOP:-}" == *"XFCE"* ]] && command -v xfce4-session-logout >/dev/null 2>&1; then
        log "Logging out via xfce4-session-logout."
        exec xfce4-session-logout --logout
    fi

    # Generic fallback: terminate current loginctl session.
    if [[ -n "${XDG_SESSION_ID:-}" ]]; then
        log "Logging out by terminating current session $XDG_SESSION_ID."
        exec loginctl terminate-session "$XDG_SESSION_ID"
    fi

    die "Could not determine how to log out this session (missing env/socket/session id)."
}

switch_to_target_tty || true
logout_current_session
