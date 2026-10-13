#!/usr/bin/env bash
# GitHub.com/PiercingXX
# Clean System: pick what to clean, see sizes first, confirm, get a
# before/after report. Only touches package-manager caches (via their own
# tools) and known cache paths in your own $HOME. Never touches Downloads,
# other users' homes, or /tmp.
#
# Usage: clean-system.sh                     interactive picker
#        clean-system.sh --categories a,b    run these categories (see --list)
#        clean-system.sh --yes               no prompts (safe defaults, or --categories;
#                                            orphans only when named in --categories)
#        clean-system.sh --dry-run           show what would run, change nothing
#        clean-system.sh --summary           reclaimable sizes only (no sudo, for bars)
#        clean-system.sh --setup             one-time maintenance setup (timers)
#        clean-system.sh --list              list category ids
# Env:   PX_NO_PAUSE=1 skips the final "Press Enter" when run from a menu
#        that pauses on its own.

set -uo pipefail

# shellcheck source=../lib/common.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

DRY_RUN=0
ASSUME_YES=0
CATEGORIES=""
MODE="menu"

usage() { sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
    case "$1" in
        -n|--dry-run)   DRY_RUN=1 ;;
        -y|--yes)       ASSUME_YES=1 ;;
        --categories)   CATEGORIES="${2:-}"; shift ;;
        --categories=*) CATEGORIES="${1#--categories=}" ;;
        --summary)      MODE="summary" ;;
        --setup)        MODE="setup" ;;
        --list)         MODE="list" ;;
        -h|--help)      usage; exit 0 ;;
        *)              err "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

refuse_root
detect_distro

LOG_FILE="$PX_STATE_DIR/clean.log"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() {
    [ "$DRY_RUN" -eq 1 ] && return 0
    mkdir -p "$PX_STATE_DIR"
    printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG_FILE"
}

# run cmd... : print in dry-run, otherwise execute and log
run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '  %s[dry-run]%s %s\n' "$BLUE" "$NC" "$*"
        return 0
    fi
    log "run: $*"
    "$@"
    local rc=$?
    [ "$rc" -ne 0 ] && log "  exit $rc"
    return "$rc"
}

# ask "Question?" : yes under --yes or --dry-run, otherwise confirm
ask() {
    [ "$ASSUME_YES" -eq 1 ] && return 0
    [ "$DRY_RUN" -eq 1 ] && return 0
    confirm "$1"
}

# ask_manual "Question?" : for steps that should never run unattended.
# --yes only reports; --dry-run shows the command.
ask_manual() {
    [ "$DRY_RUN" -eq 1 ] && return 0
    [ "$ASSUME_YES" -eq 1 ] && return 1
    confirm "$1"
}

# bytes_of path... : total bytes of the paths that exist
bytes_of() {
    local p existing=()
    for p in "$@"; do [ -e "$p" ] && existing+=("$p"); done
    [ ${#existing[@]} -gt 0 ] || { echo 0; return; }
    du -scb "${existing[@]}" 2>/dev/null | tail -n1 | cut -f1
}

human() { numfmt --to=iec --suffix=B "${1:-0}" 2>/dev/null || echo "${1:-0}B"; }

# empty_dir dir : delete the contents (dotfiles too), keep the dir
empty_dir() {
    [ -d "$1" ] || return 0
    run find "$1" -mindepth 1 -delete
}

# Free space per filesystem (/, $HOME, /var), deduplicated by device
fs_avail() {
    df --output=source,avail -B1 / "$HOME" /var 2>/dev/null | awk 'NR>1 && !seen[$1]++ {print $1, $2}'
}

section() { printf '\n%s== %s ==%s\n' "$BLUE" "$*" "$NC"; }

# ---------------------------------------------------------------------------
# Category registry
# ---------------------------------------------------------------------------
ALL_CATEGORIES=(pkgcache aur orphans journal tmpfiles flatpak containers thumbnails
                devcaches browsers trash snap pacman_lock config_files kernel_modules
                failed_units broken_symlinks)
DEFAULT_CATEGORIES=(pkgcache aur orphans journal tmpfiles flatpak thumbnails
                    pacman_lock config_files kernel_modules failed_units)
# --yes without --categories: never removes packages unattended
YES_DEFAULT_CATEGORIES=(pkgcache aur journal tmpfiles flatpak thumbnails
                        pacman_lock config_files kernel_modules failed_units)
SUDO_CATEGORIES=" pkgcache orphans journal tmpfiles snap pacman_lock config_files kernel_modules failed_units setup "

declare -A LABEL=(
    [pkgcache]="Package cache"
    [aur]="AUR build cache"
    [orphans]="Orphaned packages"
    [journal]="System journal"
    [tmpfiles]="Coredumps & temp files (systemd-tmpfiles)"
    [flatpak]="Flatpak unused runtimes & app caches"
    [containers]="Docker / Podman leftovers"
    [thumbnails]="Thumbnail cache"
    [devcaches]="Developer caches (uv/pip/npm/cargo/go...)"
    [browsers]="Browser caches (closed browsers only)"
    [trash]="Empty trash"
    [snap]="Old snap revisions"
    [pacman_lock]="Stale pacman lock"
    [config_files]="Unmerged config files (.pacnew etc.)"
    [kernel_modules]="Leftover kernel module dirs"
    [failed_units]="Failed systemd units"
    [broken_symlinks]="Broken symlinks in \$HOME (report only)"
    [setup]="Maintenance setup (one-time timers)"
)

# ---------------------------------------------------------------------------
# pkgcache
# ---------------------------------------------------------------------------
pacman_cache_dir() {
    local d
    d=$(pacman-conf CacheDir 2>/dev/null | head -n1)
    echo "${d:-/var/cache/pacman/pkg/}"
}

pkgcache_dirs() {
    case "$PKG" in
        pacman) pacman_cache_dir ;;
        apt)    echo /var/cache/apt/archives ;;
        dnf)    echo /var/cache/libdnf5; echo /var/cache/dnf ;;
        xbps)   echo /var/cache/xbps ;;
        zypper) echo /var/cache/zypp/packages ;;
        apk)    echo /etc/apk/cache ;;
    esac
}

cat_pkgcache_available() {
    case "$PKG" in
        pacman|apt|dnf|xbps|zypper) return 0 ;;
        apk) [ -d /etc/apk/cache ] ;;
        *) return 1 ;;
    esac
}

cat_pkgcache_size() {
    local dirs total
    mapfile -t dirs < <(pkgcache_dirs)
    total=$(bytes_of "${dirs[@]}")
    if [ "$PKG" = pacman ] && command_exists paccache; then
        local dir saved
        dir=$(pacman_cache_dir)
        saved=$(paccache -dk2 -c "$dir" 2>/dev/null | sed -n 's/.*disk space saved: \(.*\))/\1/p')
        echo "$(human "$total") total; keep-2 frees ${saved:-0B}"
    else
        echo "$(human "$total") total"
    fi
}

cat_pkgcache_run() {
    case "$PKG" in
        pacman)
            if ! command_exists paccache; then
                if ask "paccache (pacman-contrib) is missing. Install it? It keeps 2 versions per package for downgrades."; then
                    run pkg_install pacman-contrib
                fi
            fi
            if command_exists paccache || [ "$DRY_RUN" -eq 1 ]; then
                say "Keeping the 2 newest versions of installed packages..."
                run sudo paccache -rk2
                say "Removing every cached version of uninstalled packages..."
                run sudo paccache -ruk0
            else
                warn "Without paccache the only option is 'pacman -Sc' (keeps installed versions only, no downgrades)."
                if ask_manual "Run pacman -Sc anyway?"; then
                    run sudo pacman -Sc
                fi
            fi
            ;;
        apt)    run sudo apt-get clean ;;
        dnf)    run sudo dnf clean packages ;;
        xbps)   run sudo xbps-remove -O ;;
        zypper) run sudo zypper clean ;;
        apk)    run sudo apk cache clean ;;
    esac
}

# ---------------------------------------------------------------------------
# aur : clone dirs of uninstalled packages go, installed ones get git clean
# (built packages and downloaded sources) so rebuilds stay a re-download.
# ---------------------------------------------------------------------------
aur_roots() {
    local r
    for r in "$CACHE_HOME/paru/clone" "$CACHE_HOME/yay"; do
        [ -d "$r" ] && echo "$r"
    done
}

cat_aur_available() { is_arch_like && [ -n "$(aur_roots)" ]; }

cat_aur_size() {
    local roots
    mapfile -t roots < <(aur_roots)
    human "$(bytes_of "${roots[@]}")"
}

cat_aur_run() {
    local -A foreign=()
    local p root d base keep
    while read -r p; do foreign[$p]=1; done < <(pacman -Qqm 2>/dev/null)

    while read -r root; do
        say "Cleaning $root"
        for d in "$root"/*/; do
            d="${d%/}"
            [ -d "$d" ] || continue
            base=$(basename "$d")
            [ "$base" = repo ] && continue   # paru local repo
            keep=0
            if [ -n "${foreign[$base]:-}" ]; then
                keep=1
            else
                # split packages: pkgbase "foo" builds "foo-bar"
                for p in "${!foreign[@]}"; do
                    [[ "$p" == "$base"-* ]] && { keep=1; break; }
                done
            fi
            if [ "$keep" -eq 0 ]; then
                run rm -rf -- "$d"
            elif [ -d "$d/.git" ]; then
                run git -C "$d" clean -ffdxq
            else
                run find "$d" -maxdepth 1 -name '*.pkg.tar*' -delete
            fi
        done
    done < <(aur_roots)
}

# ---------------------------------------------------------------------------
# orphans
# ---------------------------------------------------------------------------
cat_orphans_available() {
    case "$PKG" in pacman|apt|dnf|xbps|zypper) return 0 ;; *) return 1 ;; esac
}

orphan_list() {
    case "$PKG" in
        pacman) pacman -Qtdq 2>/dev/null ;;
        apt)    apt-get -s autoremove 2>/dev/null | awk '/^Remv/{print $2}' ;;
        dnf)    dnf repoquery --unneeded -q 2>/dev/null ;;
        xbps)   xbps-query -O 2>/dev/null ;;
        zypper) zypper -q packages --unneeded 2>/dev/null | awk -F'|' '/^i/{gsub(/ /,"",$3); print $3}' ;;
    esac
}

cat_orphans_size() {
    local n
    n=$(orphan_list | grep -c .)
    echo "$n package(s)"
}

cat_orphans_run() {
    local list pass=1
    while :; do
        mapfile -t list < <(orphan_list)
        if [ ${#list[@]} -eq 0 ]; then
            ok "No orphaned packages."
            return 0
        fi
        say "Orphaned packages (pass $pass):"
        printf '  %s\n' "${list[@]}"
        case "$PKG" in
            pacman)
                ask "Remove these ${#list[@]} package(s) and their unneeded deps?" || return 0
                if [ "$DRY_RUN" -eq 1 ]; then
                    run sudo pacman -Rns -- "${list[@]}"
                    return 0
                fi
                local extra=()
                [ "$ASSUME_YES" -eq 1 ] && extra=(--noconfirm)
                log "run: pacman -Rns ${list[*]}"
                # Targets on stdin; pacman reopens the tty for its own prompt
                printf '%s\n' "${list[@]}" | sudo pacman -Rns "${extra[@]}" - || return 1
                ;;
            apt)
                ask "Remove them with apt autoremove?" || return 0
                if [ "$ASSUME_YES" -eq 1 ]; then run sudo apt-get autoremove --purge -y; else run sudo apt-get autoremove --purge; fi
                return
                ;;
            dnf)
                ask "Remove them with dnf autoremove?" || return 0
                if [ "$ASSUME_YES" -eq 1 ]; then run sudo dnf autoremove -y; else run sudo dnf autoremove; fi
                return
                ;;
            xbps)
                ask "Remove them with xbps-remove -o?" || return 0
                if [ "$ASSUME_YES" -eq 1 ]; then run sudo xbps-remove -oy; else run sudo xbps-remove -o; fi
                return
                ;;
            zypper)
                say "openSUSE has no safe autoremove; review the list and remove with: sudo zypper rm --clean-deps <pkg>"
                return 0
                ;;
        esac
        # pacman: removing orphans can orphan more; go again (interactive only)
        [ "$ASSUME_YES" -eq 1 ] && return 0
        pass=$((pass + 1))
        [ "$pass" -gt 5 ] && return 0
    done
}

# ---------------------------------------------------------------------------
# journal / tmpfiles (systemd only)
# ---------------------------------------------------------------------------
cat_journal_available() { [ "$INIT" = systemd ] && command_exists journalctl; }

cat_journal_size() {
    journalctl --disk-usage 2>/dev/null | sed -n 's/.*take up \([^ ]*\) .*/\1/p'
}

cat_journal_run() {
    say "Keeping the last 2 weeks, capped at 500M..."
    run sudo journalctl --vacuum-time=2weeks --vacuum-size=500M
}

cat_tmpfiles_available() { [ "$INIT" = systemd ] && command_exists systemd-tmpfiles; }

cat_tmpfiles_size() {
    echo "coredumps $(human "$(bytes_of /var/lib/systemd/coredump)")"
}

cat_tmpfiles_run() {
    say "Applying tmpfiles age rules (old coredumps, /var/tmp, /tmp)..."
    run sudo systemd-tmpfiles --clean
    run systemd-tmpfiles --user --clean
}

# ---------------------------------------------------------------------------
# flatpak
# ---------------------------------------------------------------------------
cat_flatpak_available() { command_exists flatpak; }

flatpak_cache_dirs() {
    local d
    for d in "$HOME"/.var/app/*/cache; do
        [ -d "$d" ] && echo "$d"
    done
}

cat_flatpak_size() {
    local dirs
    mapfile -t dirs < <(flatpak_cache_dirs)
    echo "app caches $(human "$(bytes_of "${dirs[@]}")"); unused runtimes listed on run"
}

cat_flatpak_run() {
    say "Unused runtimes/extensions:"
    if [ "$ASSUME_YES" -eq 1 ]; then
        run flatpak uninstall --unused -y --noninteractive
    else
        run flatpak uninstall --unused
    fi

    local dirs d app running
    mapfile -t dirs < <(flatpak_cache_dirs)
    [ ${#dirs[@]} -gt 0 ] || return 0
    running=" $(flatpak ps --columns=application 2>/dev/null | tr '\n' ' ') "
    if ask "Clear Flatpak app caches ($(human "$(bytes_of "${dirs[@]}")")) for apps that aren't running?"; then
        for d in "${dirs[@]}"; do
            app=$(basename "$(dirname "$d")")
            if [[ "$running" == *" $app "* ]]; then
                say "  skipping $app (running)"
                continue
            fi
            empty_dir "$d"
        done
    fi
}

# ---------------------------------------------------------------------------
# containers : dangling images, build cache and unused networks only.
# Stopped containers need a separate yes and are never removed under --yes.
# Volumes are never touched.
# ---------------------------------------------------------------------------
container_engines() {
    local e
    for e in docker podman; do
        command_exists "$e" && timeout 10 "$e" info >/dev/null 2>&1 && echo "$e"
    done
}

cat_containers_available() { command_exists docker || command_exists podman; }

cat_containers_size() {
    local e out=() r
    while read -r e; do
        r=$(timeout 15 "$e" system df --format '{{.Type}} {{.Reclaimable}}' 2>/dev/null \
            | awk '{t=$1; $1=""; sub(/^ /,""); printf "%s%s %s", (n++?", ":""), t, $0}' | tr ',' ';')
        out+=("$e: ${r:-?}")
    done < <(container_engines)
    [ ${#out[@]} -gt 0 ] || { echo "engine not running or no access"; return; }
    local IFS='|'
    echo "${out[*]}"
}

cat_containers_run() {
    local e engines
    mapfile -t engines < <(container_engines)
    if [ ${#engines[@]} -eq 0 ]; then
        warn "Docker/Podman isn't running or you don't have access (docker group)."
        return 0
    fi
    for e in "${engines[@]}"; do
        say "$e disk usage:"
        "$e" system df 2>/dev/null
        if ask "Prune $e dangling images, build cache and unused networks? (volumes are kept)"; then
            run "$e" image prune -f
            [ "$e" = docker ] && run docker builder prune -f
            run "$e" network prune -f
        fi
        local stopped
        stopped=$("$e" ps -a --filter status=exited --filter status=created -q 2>/dev/null | grep -c .)
        if [ "$stopped" -gt 0 ]; then
            "$e" ps -a --filter status=exited --filter status=created --format '  {{.Names}}  ({{.Image}}, {{.Status}})' 2>/dev/null
            if ask_manual "Also remove these $stopped stopped $e container(s)?"; then
                run "$e" container prune -f
            fi
        fi
    done
}

# ---------------------------------------------------------------------------
# thumbnails
# ---------------------------------------------------------------------------
cat_thumbnails_available() { [ -d "$CACHE_HOME/thumbnails" ] || [ -d "$HOME/.thumbnails" ]; }
cat_thumbnails_size() { human "$(bytes_of "$CACHE_HOME/thumbnails" "$HOME/.thumbnails")"; }
cat_thumbnails_run() {
    empty_dir "$CACHE_HOME/thumbnails"
    empty_dir "$HOME/.thumbnails"
}

# ---------------------------------------------------------------------------
# devcaches : one line per tool "id|path|label"; cleaned with the tool's own
# command when it has one.
# ---------------------------------------------------------------------------
devcache_entries() {
    local p
    if command_exists uv; then p=$(uv cache dir 2>/dev/null); [ -d "$p" ] && echo "uv|$p|uv"; fi
    if command_exists pip; then p=$(pip cache dir 2>/dev/null); [ -d "$p" ] && echo "pip|$p|pip"; fi
    if command_exists npm; then p="$HOME/.npm/_cacache"; [ -d "$p" ] && echo "npm|$p|npm"; fi
    if command_exists pnpm; then p=$(pnpm store path 2>/dev/null); [ -d "$p" ] && echo "pnpm|$p|pnpm store"; fi
    if command_exists yarn; then p=$(yarn cache dir 2>/dev/null); [ -d "$p" ] && echo "yarn|$p|yarn"; fi
    p="${CARGO_HOME:-$HOME/.cargo}/registry/cache"; [ -d "$p" ] && echo "cargo|$p|cargo registry"
    if command_exists go; then p=$(go env GOCACHE 2>/dev/null); [ -d "$p" ] && echo "go|$p|go build cache"; fi
    if command_exists go; then p=$(go env GOMODCACHE 2>/dev/null); [ -d "$p" ] && echo "gomod|$p|go module cache"; fi
    p="${SCCACHE_DIR:-$CACHE_HOME/sccache}"; [ -d "$p" ] && echo "sccache|$p|sccache"
    p="${PLAYWRIGHT_BROWSERS_PATH:-$CACHE_HOME/ms-playwright}"; [ -d "$p" ] && echo "playwright|$p|playwright browsers"
}

cat_devcaches_available() { [ -n "$(devcache_entries)" ]; }

cat_devcaches_size() {
    local id path lbl paths=()
    while IFS='|' read -r id path lbl; do paths+=("$path"); done < <(devcache_entries)
    human "$(bytes_of "${paths[@]}")"
}

devcache_clean() {
    local id="$1" path="$2"
    case "$id" in
        uv)         run uv cache clean ;;
        pip)        run pip cache purge ;;
        npm)        run npm cache clean --force ;;
        pnpm)       run pnpm store prune ;;
        yarn)       run yarn cache clean ;;
        go)         run go clean -cache ;;
        gomod)      run go clean -modcache ;;
        sccache)    command_exists sccache && run sccache --stop-server >/dev/null 2>&1; empty_dir "$path" ;;
        *)          empty_dir "$path" ;;
    esac
}

cat_devcaches_run() {
    local id path lbl size entries=() options=() chosen=()
    local -A by_option=()
    while IFS='|' read -r id path lbl; do
        size=$(human "$(bytes_of "$path")")
        entries+=("$id|$path")
        options+=("$lbl ($size)")
        by_option["$lbl ($size)"]="$id|$path"
    done < <(devcache_entries)

    if [ "$ASSUME_YES" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
        chosen=("${options[@]}")
    elif command_exists gum; then
        mapfile -t chosen < <(printf '%s\n' "${options[@]}" | gum choose --no-limit --header "Which developer caches? (space to pick, enter to confirm)")
    else
        local o
        for o in "${options[@]}"; do
            confirm "Clear $o?" && chosen+=("$o")
        done
    fi

    local o
    for o in "${chosen[@]}"; do
        [ -n "${by_option[$o]:-}" ] || continue
        IFS='|' read -r id path <<<"${by_option[$o]}"
        say "Clearing $o"
        devcache_clean "$id" "$path"
    done
}

# ---------------------------------------------------------------------------
# browsers : cache dirs only, and only when that browser is closed
# "name|cache dir|process names"
# ---------------------------------------------------------------------------
browser_entries() {
    local line name dir procs
    for line in \
        "Firefox|$CACHE_HOME/mozilla/firefox|firefox firefox-bin" \
        "LibreWolf|$CACHE_HOME/librewolf|librewolf" \
        "Zen|$CACHE_HOME/zen|zen zen-bin" \
        "Chromium|$CACHE_HOME/chromium|chromium" \
        "Chrome|$CACHE_HOME/google-chrome|chrome" \
        "Brave|$CACHE_HOME/BraveSoftware|brave" \
        "Vivaldi|$CACHE_HOME/vivaldi|vivaldi-bin"; do
        IFS='|' read -r name dir procs <<<"$line"
        [ -d "$dir" ] && echo "$name|$dir|$procs"
    done
}

browser_running() {
    local p
    for p in $1; do pgrep -x "$p" >/dev/null 2>&1 && return 0; done
    return 1
}

cat_browsers_available() { [ -n "$(browser_entries)" ]; }

cat_browsers_size() {
    local name dir procs paths=()
    while IFS='|' read -r name dir procs; do paths+=("$dir"); done < <(browser_entries)
    human "$(bytes_of "${paths[@]}")"
}

cat_browsers_run() {
    local name dir procs
    while IFS='|' read -r name dir procs; do
        if browser_running "$procs"; then
            warn "  $name is running; close it to clear its cache."
            continue
        fi
        say "Clearing $name cache ($(human "$(bytes_of "$dir")"))"
        empty_dir "$dir"
    done < <(browser_entries)
}

# ---------------------------------------------------------------------------
# trash : home trash plus per-volume .Trash-$UID on mounted drives
# ---------------------------------------------------------------------------
trash_dirs() {
    local uid d
    uid=$(id -u)
    [ -d "$DATA_HOME/Trash" ] && echo "$DATA_HOME/Trash"
    for d in /media/*/.Trash-"$uid" /media/*/*/.Trash-"$uid" /run/media/*/*/.Trash-"$uid" /mnt/*/.Trash-"$uid"; do
        [ -d "$d" ] && echo "$d"
    done
}

cat_trash_available() { [ -n "$(trash_dirs)" ]; }

cat_trash_size() {
    local dirs
    mapfile -t dirs < <(trash_dirs)
    human "$(bytes_of "${dirs[@]}")"
}

cat_trash_run() {
    local dirs d
    mapfile -t dirs < <(trash_dirs)
    say "Trash locations:"
    for d in "${dirs[@]}"; do printf '  %s (%s)\n' "$d" "$(human "$(bytes_of "$d")")"; done
    ask "Permanently delete everything in the trash?" || return 0
    if command_exists gio && run gio trash --empty 2>/dev/null; then
        :
    elif command_exists trash-empty && run trash-empty -f 2>/dev/null; then
        :
    fi
    # Anything gio/trash-cli couldn't reach (no gvfs in a TTY, unmounted helpers)
    for d in "${dirs[@]}"; do
        empty_dir "$d/files"
        empty_dir "$d/info"
        empty_dir "$d/expunged"
    done
}

# ---------------------------------------------------------------------------
# snap
# ---------------------------------------------------------------------------
snap_disabled() {
    # Columns: Name Version Rev Tracking Publisher Notes
    snap list --all 2>/dev/null | awk 'NR>1 && /disabled/ {print $1, $3}'
}

cat_snap_available() { command_exists snap; }
cat_snap_size() { echo "$(snap_disabled | grep -c .) disabled revision(s)"; }

cat_snap_run() {
    run sudo snap set system refresh.retain=2
    local name rev
    while read -r name rev; do
        [ -n "$name" ] || continue
        run sudo snap remove "$name" --revision="$rev"
    done < <(snap_disabled)
}

# ---------------------------------------------------------------------------
# pacman_lock : only removed when no package manager is running
# ---------------------------------------------------------------------------
pacman_lock_path() {
    local d
    d=$(pacman-conf DBPath 2>/dev/null | head -n1)
    echo "${d:-/var/lib/pacman/}db.lck"
}

pkgmgr_running() {
    pgrep -x pacman >/dev/null 2>&1 || pgrep -x paru >/dev/null 2>&1 \
        || pgrep -x yay >/dev/null 2>&1 || pgrep -x pamac >/dev/null 2>&1 \
        || pgrep -f 'pamac-daemon|packagekitd' >/dev/null 2>&1
}

cat_pacman_lock_available() { is_arch_like; }

cat_pacman_lock_size() {
    if [ -e "$(pacman_lock_path)" ]; then
        pkgmgr_running && echo "locked (pacman running)" || echo "STALE lock present"
    else
        echo "ok"
    fi
}

cat_pacman_lock_run() {
    local lock
    lock=$(pacman_lock_path)
    if [ ! -e "$lock" ]; then
        ok "No pacman lock present."
        return 0
    fi
    if pkgmgr_running || { command_exists fuser && fuser "$lock" >/dev/null 2>&1; }; then
        warn "A package manager is running; leaving $lock alone."
        return 0
    fi
    warn "Stale lock: $lock ($(stat -c '%y' "$lock" 2>/dev/null | cut -d. -f1))"
    if ask_manual "Remove the stale pacman lock?"; then
        run sudo rm -f -- "$lock"
    fi
}

# ---------------------------------------------------------------------------
# config_files : .pacnew/.pacsave and the other distros' equivalents
# ---------------------------------------------------------------------------
config_file_list() {
    case "$PKG" in
        pacman)
            if command_exists pacdiff; then
                pacdiff -o 2>/dev/null
            else
                find /etc -xdev \( -name '*.pacnew' -o -name '*.pacsave' \) 2>/dev/null
            fi ;;
        apt)        find /etc -xdev \( -name '*.dpkg-new' -o -name '*.dpkg-dist' -o -name '*.dpkg-old' -o -name '*.ucf-dist' \) 2>/dev/null ;;
        dnf|zypper) find /etc -xdev \( -name '*.rpmnew' -o -name '*.rpmsave' \) 2>/dev/null ;;
        xbps)       find /etc -xdev -name '*.new-*' 2>/dev/null ;;
        apk)        find /etc -xdev -name '*.apk-new' 2>/dev/null ;;
    esac
}

cat_config_files_available() { [ -n "$PKG" ]; }
cat_config_files_size() { echo "$(config_file_list | grep -c .) file(s)"; }

cat_config_files_run() {
    local files
    mapfile -t files < <(config_file_list)
    if [ ${#files[@]} -eq 0 ]; then
        ok "No unmerged config files."
        return 0
    fi
    say "Config files waiting to be merged:"
    printf '  %s\n' "${files[@]}"
    if [ "$PKG" = pacman ]; then
        if ! command_exists pacdiff; then
            say "Install pacman-contrib for pacdiff to merge them interactively."
            return 0
        fi
        if ask_manual "Review and merge them now with pacdiff?"; then
            if command_exists nvim; then
                run sudo env DIFFPROG="nvim -d" pacdiff
            else
                run sudo pacdiff
            fi
        fi
    else
        say "Compare each with its live file (e.g. 'sudo nvim -d FILE FILE.new'), merge, then delete the leftover."
    fi
}

# ---------------------------------------------------------------------------
# kernel_modules : /usr/lib/modules/<ver> owned by no package and not the
# running kernel (DKMS leftovers after kernel upgrades)
# ---------------------------------------------------------------------------
modules_root() {
    if [ -d /usr/lib/modules ]; then echo /usr/lib/modules; else echo /lib/modules; fi
}

dir_owned() {
    case "$PKG" in
        pacman)     pacman -Qqo "$1" >/dev/null 2>&1 ;;
        apt)        dpkg -S "$1" >/dev/null 2>&1 ;;
        dnf|zypper) rpm -qf "$1" >/dev/null 2>&1 ;;
        *)          return 0 ;;   # can't tell: treat as owned, never offer removal
    esac
}

leftover_module_dirs() {
    local running d
    running=$(uname -r)
    for d in "$(modules_root)"/*/; do
        d="${d%/}"
        [ -d "$d" ] || continue
        [ "$(basename "$d")" = "$running" ] && continue
        dir_owned "$d" || echo "$d"
    done
}

cat_kernel_modules_available() {
    case "$PKG" in pacman|apt|dnf|zypper) [ -d "$(modules_root)" ] ;; *) return 1 ;; esac
}

cat_kernel_modules_size() {
    local dirs
    mapfile -t dirs < <(leftover_module_dirs)
    echo "${#dirs[@]} dir(s), $(human "$(bytes_of "${dirs[@]}")")"
}

cat_kernel_modules_run() {
    local dirs d
    mapfile -t dirs < <(leftover_module_dirs)
    if [ ${#dirs[@]} -eq 0 ]; then
        ok "No leftover module directories (running: $(uname -r))."
        return 0
    fi
    say "Module dirs owned by no package (running kernel $(uname -r) is excluded):"
    for d in "${dirs[@]}"; do printf '  %s (%s)\n' "$d" "$(human "$(bytes_of "$d")")"; done
    if ask_manual "Remove these ${#dirs[@]} directories?"; then
        for d in "${dirs[@]}"; do run sudo rm -rf -- "$d"; done
    fi
}

# ---------------------------------------------------------------------------
# failed_units
# ---------------------------------------------------------------------------
cat_failed_units_available() { [ "$INIT" = systemd ]; }

failed_units() {
    systemctl --failed --no-legend --plain 2>/dev/null | awk '{print "system: " $1}'
    systemctl --user --failed --no-legend --plain 2>/dev/null | awk '{print "user:   " $1}'
}

cat_failed_units_size() { echo "$(failed_units | grep -c .) unit(s)"; }

cat_failed_units_run() {
    local units
    mapfile -t units < <(failed_units)
    if [ ${#units[@]} -eq 0 ]; then
        ok "No failed units."
        return 0
    fi
    say "Failed units (check with 'systemctl status UNIT' / 'journalctl -u UNIT'):"
    printf '  %s\n' "${units[@]}"
    if ask "Clear the failed state so they stop showing up?"; then
        run sudo systemctl reset-failed
        run systemctl --user reset-failed
    fi
}

# ---------------------------------------------------------------------------
# broken_symlinks : report only, never deleted (many are intentional)
# ---------------------------------------------------------------------------
cat_broken_symlinks_available() { return 0; }
cat_broken_symlinks_size() { echo "report only"; }

cat_broken_symlinks_run() {
    local links out="$PX_STATE_DIR/broken-symlinks.txt"
    say "Scanning \$HOME for broken symlinks (skipping caches, .git, node_modules)..."
    mapfile -t links < <(timeout 120 find "$HOME" -xdev \
        \( -path "$CACHE_HOME" -o -name .git -o -name node_modules -o -path "$DATA_HOME/Steam" -o -path "$DATA_HOME/Trash" \) -prune \
        -o -xtype l -print 2>/dev/null)
    if [ ${#links[@]} -eq 0 ]; then
        ok "No broken symlinks found."
        return 0
    fi
    printf '  %s\n' "${links[@]:0:50}"
    [ ${#links[@]} -gt 50 ] && say "  ... and $(( ${#links[@]} - 50 )) more"
    if [ "$DRY_RUN" -eq 0 ]; then
        mkdir -p "$PX_STATE_DIR"
        printf '%s\n' "${links[@]}" >"$out"
        say "Full list saved to $out. Nothing was deleted."
    fi
}

# ---------------------------------------------------------------------------
# Maintenance setup: timers so most of this happens on its own
# ---------------------------------------------------------------------------
REFLECTOR_CONF=/etc/xdg/reflector/reflector.conf
REFLECTOR_DEFAULTS='--save /etc/pacman.d/mirrorlist
--protocol https
--age 12
--latest 30
--sort rate
--number 15
--download-timeout 10'

run_setup() {
    section "${LABEL[setup]}"
    if [ "$INIT" != systemd ]; then
        warn "Timers need systemd; this system uses $INIT."
        if is_arch_like; then
            say "On Artix, add a weekly cron job instead, e.g.: 0 3 * * 0 paccache -rk2 && paccache -ruk0"
        fi
        return 0
    fi

    if systemctl list-unit-files fstrim.timer >/dev/null 2>&1 && ! systemctl is-enabled --quiet fstrim.timer 2>/dev/null; then
        ask "Enable weekly SSD TRIM (fstrim.timer)?" && run sudo systemctl enable --now fstrim.timer
    else
        ok "fstrim.timer: enabled or not available."
    fi

    [ "$DISTRO" = arch ] || { say "paccache/reflector timers are Arch-only; nothing more to set up."; return 0; }

    if ! command_exists paccache && ask "Install pacman-contrib (paccache, pacdiff, checkupdates)?"; then
        run pkg_install pacman-contrib
    fi
    if systemctl list-unit-files paccache.timer 2>/dev/null | grep -q paccache; then
        if ! systemctl is-enabled --quiet paccache.timer 2>/dev/null; then
            ask "Enable weekly package-cache pruning (paccache.timer, keeps 3 versions)?" \
                && run sudo systemctl enable --now paccache.timer
        else
            ok "paccache.timer: already enabled."
        fi
    fi

    # Manjaro ranks mirrors with pacman-mirrors; leave it alone there
    [ "${DISTRO_ID:-}" = manjaro ] && return 0

    if ! command_exists reflector; then
        ask "Install reflector for weekly mirror ranking?" && run pkg_install reflector
    fi
    if command_exists reflector || [ "$DRY_RUN" -eq 1 ]; then
        if [ -f "$REFLECTOR_CONF" ] && [ "$(grep -v '^\s*#' "$REFLECTOR_CONF" | grep -c .)" -gt 0 ]; then
            say "Current $REFLECTOR_CONF:"
            grep -v '^\s*#' "$REFLECTOR_CONF" | grep . | sed 's/^/  /'
            if ask_manual "Replace it with the PiercingXX defaults (https, 15 fastest of the 30 freshest)?"; then
                run sudo cp -a "$REFLECTOR_CONF" "$REFLECTOR_CONF.bak"
                write_reflector_conf
            fi
        else
            write_reflector_conf
        fi
        if ! systemctl is-enabled --quiet reflector.timer 2>/dev/null; then
            ask "Enable weekly mirror ranking (reflector.timer)?" && run sudo systemctl enable --now reflector.timer
        else
            ok "reflector.timer: already enabled."
        fi
    fi
}

write_reflector_conf() {
    if [ "$DRY_RUN" -eq 1 ]; then
        run sudo tee "$REFLECTOR_CONF"
        return 0
    fi
    sudo install -d -m 755 "$(dirname "$REFLECTOR_CONF")"
    printf '# Written by PiercingXX clean-system.sh\n%s\n' "$REFLECTOR_DEFAULTS" | sudo tee "$REFLECTOR_CONF" >/dev/null
    log "wrote $REFLECTOR_CONF"
    ok "Wrote $REFLECTOR_CONF"
}

# ---------------------------------------------------------------------------
# Modes
# ---------------------------------------------------------------------------
available_categories() {
    local c
    for c in "${ALL_CATEGORIES[@]}"; do
        "cat_${c}_available" 2>/dev/null && echo "$c"
    done
}

if [ "$MODE" = list ]; then
    for c in "${ALL_CATEGORIES[@]}" setup; do
        if [ "$c" = setup ] || "cat_${c}_available" 2>/dev/null; then state="available"; else state="n/a here"; fi
        printf '%-16s %-48s %s\n' "$c" "${LABEL[$c]}" "$state"
    done
    exit 0
fi

if [ "$MODE" = summary ]; then
    # Cheap estimates only: no sudo, no network, no container engines
    for c in pkgcache aur journal thumbnails devcaches browsers trash; do
        "cat_${c}_available" 2>/dev/null || continue
        if [ "$c" = pkgcache ]; then
            mapfile -t dirs < <(pkgcache_dirs)
            size=$(human "$(bytes_of "${dirs[@]}")")
        else
            size=$("cat_${c}_size")
        fi
        printf '%s\t%s\n' "${LABEL[$c]}" "$size"
    done
    if cat_orphans_available && [ "$PKG" != dnf ]; then
        printf '%s\t%s\n' "${LABEL[orphans]}" "$(cat_orphans_size)"
    fi
    exit 0
fi

if [ "$MODE" = setup ]; then
    [ "$DRY_RUN" -eq 1 ] || sudo -v || die "sudo is required."
    run_setup
    exit 0
fi

# --- menu / --categories / --yes ------------------------------------------
mapfile -t AVAILABLE < <(available_categories)
SELECTED=()

if [ -n "$CATEGORIES" ]; then
    IFS=',' read -ra wanted <<<"${CATEGORIES//-/_}"
    for c in "${wanted[@]}"; do
        c="${c// /}"
        [ -n "$c" ] || continue
        if [ "$c" = setup ]; then SELECTED+=(setup); continue; fi
        if [[ " ${ALL_CATEGORIES[*]} " != *" $c "* ]]; then
            warn "Unknown category: $c (see --list)"
        elif [[ " ${AVAILABLE[*]} " != *" $c "* ]]; then
            warn "Skipping $c: not available on this system."
        else
            SELECTED+=("$c")
        fi
    done
elif [ "$ASSUME_YES" -eq 1 ]; then
    for c in "${YES_DEFAULT_CATEGORIES[@]}"; do
        [[ " ${AVAILABLE[*]} " == *" $c "* ]] && SELECTED+=("$c")
    done
else
    [ -t 0 ] || die "No terminal for the picker; pass --categories or --yes (see --help)."
    clear 2>/dev/null
    say "Measuring what can be cleaned..."
    declare -A ID_OF=()
    OPTIONS=()
    PRESELECT=()
    for c in "${AVAILABLE[@]}" setup; do
        if [ "$c" = setup ]; then
            line="${LABEL[setup]}"
        else
            line="${LABEL[$c]}  ($("cat_${c}_size" 2>/dev/null))"
        fi
        line="${line//,/;}"   # gum --selected is comma-separated
        ID_OF["$line"]="$c"
        OPTIONS+=("$line")
        [[ " ${DEFAULT_CATEGORIES[*]} " == *" $c "* ]] && PRESELECT+=("$line")
    done

    if command_exists gum; then
        preselect_csv=$(IFS=','; echo "${PRESELECT[*]}")
        mapfile -t picked < <(printf '%s\n' "${OPTIONS[@]}" | gum choose --no-limit \
            --height $(( ${#OPTIONS[@]} + 2 )) \
            --header "Clean System: space toggles, enter confirms (pre-checked = safe defaults)" \
            --selected "$preselect_csv")
    else
        i=1
        for line in "${OPTIONS[@]}"; do
            mark=" "
            [[ " ${PRESELECT[*]} " == *" $line "* ]] && mark="x"
            printf '%2d) [%s] %s\n' "$i" "$mark" "$line"
            i=$((i + 1))
        done
        read -r -p "Numbers to run (e.g. 1 3 7), Enter = [x] defaults, q = quit: " answer
        [[ "$answer" =~ ^[Qq] ]] && exit 0
        picked=()
        if [ -z "$answer" ]; then
            picked=("${PRESELECT[@]}")
        else
            for n in $answer; do
                [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le ${#OPTIONS[@]} ] && picked+=("${OPTIONS[$((n - 1))]}")
            done
        fi
    fi
    for line in "${picked[@]}"; do
        [ -n "${ID_OF[$line]:-}" ] && SELECTED+=("${ID_OF[$line]}")
    done
fi

if [ ${#SELECTED[@]} -eq 0 ]; then
    say "Nothing selected."
    exit 0
fi

# sudo once up front (and keep it alive) if anything selected needs it
needs_sudo=0
for c in "${SELECTED[@]}"; do
    [[ "$SUDO_CATEGORIES" == *" $c "* ]] && needs_sudo=1
done
if [ "$needs_sudo" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
    sudo -v || die "sudo is required for the selected categories."
    ( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 50; done ) &
    KEEPALIVE_PID=$!
    trap 'kill "$KEEPALIVE_PID" 2>/dev/null' EXIT
fi

[ "$DRY_RUN" -eq 1 ] && say "DRY RUN: nothing will be changed."
log "=== clean-system: ${SELECTED[*]}"
mapfile -t BEFORE < <(fs_avail)

declare -A RESULT=()
for c in "${SELECTED[@]}"; do
    if [ "$c" = setup ]; then
        run_setup
        RESULT[$c]="done"
        continue
    fi
    section "${LABEL[$c]}"
    if "cat_${c}_run"; then RESULT[$c]="done"; else RESULT[$c]="errors"; fi
done

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
section "Summary"
for c in "${SELECTED[@]}"; do
    printf '  %-48s %s\n' "${LABEL[$c]}" "${RESULT[$c]:-skipped}"
done

if [ "$DRY_RUN" -eq 0 ]; then
    total=0
    for line in "${BEFORE[@]}"; do
        read -r dev before <<<"$line"
        after=$(fs_avail | awk -v d="$dev" '$1==d {print $2}')
        [ -n "$after" ] || continue
        delta=$(( after - before ))
        total=$(( total + delta ))
        mnt=$(df --output=target "$dev" 2>/dev/null | tail -n1)
        if [ "$delta" -ge 0 ]; then
            printf '  %-48s +%s free\n' "${mnt:-$dev}" "$(human "$delta")"
        else
            printf '  %-48s -%s free\n' "${mnt:-$dev}" "$(human $(( -delta )))"
        fi
    done
    if [ "$total" -ge 0 ]; then
        ok "Reclaimed about $(human "$total")."
        log "reclaimed $total bytes"
    fi
    say "Log: $LOG_FILE"
    notify_replace clean-system low 5000 edit-clear "Clean System" "Reclaimed about $(human "$(( total > 0 ? total : 0 ))")" 2>/dev/null
fi

if [ -t 0 ] && [ "$ASSUME_YES" -eq 0 ] && [ -z "$CATEGORIES" ] && [ "${PX_NO_PAUSE:-0}" != 1 ]; then
    pause "Press Enter to return..."
fi
exit 0
