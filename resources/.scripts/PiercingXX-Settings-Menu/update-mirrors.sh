#!/usr/bin/env bash
# GitHub.com/PiercingXX
# Update Mirrors: rank pacman mirrors, validate the result, keep a backup.
# Arch-based systems only. Never syncs or upgrades; run a full update after.
#
# Usage: update-mirrors.sh             interactive
#        update-mirrors.sh --yes       no prompts (fast defaults)
#        update-mirrors.sh --config    use /etc/xdg/reflector/reflector.conf
#        update-mirrors.sh --fast      use the built-in defaults
#        update-mirrors.sh --dry-run   show what would run, change nothing
# Env:   PX_NO_PAUSE=1 skips the final "Press Enter".

set -uo pipefail

# shellcheck source=../lib/common.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

DRY_RUN=0
ASSUME_YES=0
PROFILE=""   # config|fast|"" (ask)

usage() { sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=1 ;;
        -y|--yes)     ASSUME_YES=1 ;;
        --config)     PROFILE="config" ;;
        --fast)       PROFILE="fast" ;;
        -h|--help)    usage; exit 0 ;;
        *)            err "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

refuse_root
detect_distro

MIRRORLIST=/etc/pacman.d/mirrorlist
REFLECTOR_CONF=/etc/xdg/reflector/reflector.conf
FAST_ARGS=(--protocol https --age 12 --latest 30 --sort rate --number 15 --download-timeout 10)
MIN_SERVERS=3
KEEP_BACKUPS=3
TMP_FILES=()
trap 'rm -f "${TMP_FILES[@]}"' EXIT

finish() {
    local rc="$1" msg="$2"
    if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && [ "$DRY_RUN" -eq 0 ]; then
        if [ "$rc" -eq 0 ]; then
            notify_replace mirrors normal 5000 emblem-ok-symbolic "Mirror Update" "$msg"
        else
            notify_replace mirrors critical 8000 dialog-error "Mirror Update" "$msg"
        fi
    fi
    if [ -t 0 ] && [ "$ASSUME_YES" -eq 0 ] && [ "${PX_NO_PAUSE:-0}" != 1 ]; then
        pause "Press Enter to return..."
    fi
    exit "$rc"
}

ask() {
    [ "$ASSUME_YES" -eq 1 ] && return 0
    [ "$DRY_RUN" -eq 1 ] && return 0
    confirm "$1"
}

# run cmd... : print in dry-run, otherwise execute
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '  %s[dry-run]%s %s\n' "$BLUE" "$NC" "$*"
        return 0
    fi
    "$@"
}

server_count() { grep -c '^[[:space:]]*Server[[:space:]]*=' "$1" 2>/dev/null; }

new_tmp() {
    local t
    t=$(mktemp "${TMPDIR:-/tmp}/px-mirrorlist.XXXXXX")
    TMP_FILES+=("$t")
    echo "$t"
}

# install_mirrorlist NEWFILE TARGET : validate, back up, install, prune backups
install_mirrorlist() {
    local new="$1" target="$2" n
    if [ "$DRY_RUN" -eq 1 ]; then
        run sudo cp -a "$target" "$target.bak.<timestamp>"
        run sudo install -m 644 "$new" "$target"
        return 0
    fi
    n=$(server_count "$new")
    if [ "${n:-0}" -lt "$MIN_SERVERS" ]; then
        err "The new list has only ${n:-0} server(s) (need $MIN_SERVERS+). Keeping $target unchanged."
        return 1
    fi
    if [ -f "$target" ]; then
        sudo cp -a "$target" "$target.bak.$(date +%Y%m%d-%H%M%S)" || { err "Could not back up $target."; return 1; }
        # Keep only the newest few backups
        local old
        while read -r old; do
            sudo rm -f -- "$old"
        done < <(ls -1t "$target".bak.* 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)))
    fi
    sudo install -m 644 "$new" "$target" || { err "Could not write $target."; return 1; }
    ok "Wrote $n mirrors to $target (backup kept as $target.bak.*)."
    say "Top mirrors:"
    grep -m5 '^[[:space:]]*Server' "$target" | sed 's/^[[:space:]]*Server[[:space:]]*=[[:space:]]*/  /'
}

# rank_with_reflector OUTFILE
rank_with_reflector() {
    local out="$1" args=()
    if [ "$PROFILE" = config ]; then
        args=("@$REFLECTOR_CONF")
    else
        args=("${FAST_ARGS[@]}")
    fi
    say "Ranking mirrors with reflector ${args[*]} ..."
    # reflector only downloads; it doesn't need root to write a temp file.
    # --save after @conf overrides the conf's own --save.
    run reflector "${args[@]}" --save "$out"
}

# rank_with_rate_mirrors OUTFILE [arch|artix]
rank_with_rate_mirrors() {
    local out="$1" target="${2:-arch}"
    say "Ranking mirrors with rate-mirrors ($target)..."
    if [ "$DRY_RUN" -eq 1 ]; then
        run rate-mirrors --protocol https "$target"
        return 0
    fi
    rate-mirrors --protocol https "$target" >"$out"
}

# rank_with_archweb OUTFILE : last resort, status-sorted list from archlinux.org
rank_with_archweb() {
    local out="$1"
    local url='https://archlinux.org/mirrorlist/?country=all&protocol=https&ip_version=4&use_mirror_status=on'
    say "Fetching the status-sorted mirror list from archlinux.org..."
    if [ "$DRY_RUN" -eq 1 ]; then
        run curl -fsSL "$url"
        return 0
    fi
    curl -fsSL "$url" | sed 's/^#Server/Server/' \
        | awk '/^Server/ { if (++n > 20) next } { print }' >"$out"
}

# rank_arch TARGET : Arch mirrors into TARGET, best tool first
rank_arch() {
    local target="$1" tmp
    tmp=$(new_tmp)

    if ! command_exists reflector && ask "reflector isn't installed. Install it?"; then
        run pkg_install reflector || warn "Could not install reflector (a broken mirrorlist can cause this); trying fallbacks."
    fi

    if [ -z "$PROFILE" ]; then
        if [ -f "$REFLECTOR_CONF" ] && [ "$ASSUME_YES" -eq 0 ] && [ -t 0 ]; then
            say "Your $REFLECTOR_CONF:"
            grep -v '^\s*#' "$REFLECTOR_CONF" | grep . | sed 's/^/  /'
            if confirm "Use those settings? (No = fast defaults: https, 15 fastest of the 30 freshest)"; then
                PROFILE="config"
            else
                PROFILE="fast"
            fi
        else
            PROFILE="fast"
        fi
    fi
    [ "$PROFILE" = config ] && [ ! -f "$REFLECTOR_CONF" ] && { warn "$REFLECTOR_CONF not found; using fast defaults."; PROFILE="fast"; }

    if command_exists reflector || [ "$DRY_RUN" -eq 1 ]; then
        rank_with_reflector "$tmp" && install_mirrorlist "$tmp" "$target" && return 0
        warn "reflector failed or returned too few mirrors."
    fi
    if command_exists rate-mirrors; then
        rank_with_rate_mirrors "$tmp" arch && install_mirrorlist "$tmp" "$target" && return 0
        warn "rate-mirrors failed."
    fi
    if command_exists curl; then
        rank_with_archweb "$tmp" && install_mirrorlist "$tmp" "$target" && return 0
    fi
    err "No way to rank mirrors worked. $target was left unchanged."
    return 1
}

handle_pacnew() {
    local target="$1"
    [ -f "$target.pacnew" ] || return 0
    say "$target.pacnew exists (a newer default list from a package update)."
    say "The freshly ranked list supersedes it."
    if [ "$ASSUME_YES" -eq 0 ] && ask "Delete $target.pacnew?"; then
        run sudo rm -f -- "$target.pacnew"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if ! is_arch_like; then
    warn "Mirror ranking is for Arch-based systems (detected: ${DISTRO_ID:-unknown})."
    case "$DISTRO" in
        debian) say "Debian/Ubuntu use deb.debian.org / archive.ubuntu.com CDNs; nothing to rank." ;;
        fedora) say "dnf picks the fastest mirror itself (fastestmirror=True in /etc/dnf/dnf.conf)." ;;
        suse)   say "openSUSE uses MirrorCache redirects; nothing to rank." ;;
        void)   say "Pick a mirror with: sudo xmirror" ;;
        alpine) say "Pick a mirror with: sudo setup-apkrepos -f" ;;
    esac
    finish 0 "Nothing to do on ${DISTRO_ID:-this system}."
fi

if [ "$DRY_RUN" -eq 1 ]; then
    say "DRY RUN: nothing will be changed."
else
    sudo -v || die "sudo is required."
    clear 2>/dev/null
fi
say "Updating mirrors..."

rc=0
case "${DISTRO_ID:-}" in
    manjaro)
        if command_exists pacman-mirrors; then
            run sudo pacman-mirrors --fasttrack 15 --api --protocol https || rc=1
        else
            err "pacman-mirrors not found."; rc=1
        fi
        ;;
    cachyos)
        if command_exists cachyos-rate-mirrors; then
            # Ranks both the CachyOS and Arch lists and keeps its own backups
            run sudo cachyos-rate-mirrors || rc=1
        else
            rank_arch "$MIRRORLIST" || rc=1
        fi
        ;;
    artix)
        # Artix's main list holds Artix mirrors; Arch's reflector must not touch it
        if command_exists rate-mirrors; then
            tmp=$(new_tmp)
            rank_with_rate_mirrors "$tmp" artix && install_mirrorlist "$tmp" "$MIRRORLIST" || rc=1
        else
            warn "Artix mirrors need rate-mirrors (AUR: rate-mirrors-bin). Leaving $MIRRORLIST unchanged."
        fi
        # Arch repos enabled via artix-archlinux-support use mirrorlist-arch
        if [ -f /etc/pacman.d/mirrorlist-arch ]; then
            rank_arch /etc/pacman.d/mirrorlist-arch || rc=1
        fi
        ;;
    endeavouros)
        rank_arch "$MIRRORLIST" || rc=1
        if command_exists eos-rankmirrors; then
            say "Ranking EndeavourOS mirrors..."
            run sudo eos-rankmirrors || rc=1
        fi
        ;;
    *)
        rank_arch "$MIRRORLIST" || rc=1
        ;;
esac

handle_pacnew "$MIRRORLIST"
[ -f /etc/pacman.d/mirrorlist-arch ] && handle_pacnew /etc/pacman.d/mirrorlist-arch

echo
if [ "$rc" -eq 0 ]; then
    ok "Mirrors updated. Run a full update (Update System, or sudo pacman -Syu) to use them."
    finish 0 "Mirrors updated. Run a full system update next."
else
    err "Mirror update had problems; see above. Existing lists were kept where ranking failed."
    finish 1 "Mirror update failed; old mirrorlist kept."
fi
