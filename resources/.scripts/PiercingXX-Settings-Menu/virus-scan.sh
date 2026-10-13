#!/bin/bash
# GitHub.com/PiercingXX

#########################################################
# Virus Scan with ClamAV
#
# Usage: virus-scan.sh                     interactive menu
#        virus-scan.sh --update-db         update signatures only (safe for other scripts)
#        virus-scan.sh --status            print ClamAV / signature / quarantine status
#        virus-scan.sh --preset NAME [PATH] [--no-tui] [--move] [--strict]
#              NAME: fast | downloads | quick | full | custom PATH
#        virus-scan.sh --help
#
# Exit codes (scans): 0 clean, 1 infected files found, 2 errors.
#########################################################

set -o pipefail
umask 077

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
# shellcheck disable=SC1091
. "$(dirname "$SCRIPT_PATH")/../lib/common.sh"
detect_distro

# Tunables (override via env vars)
# MAX_* limits only apply to clamscan. clamdscan uses clamd.conf
# (MaxFileSize, MaxScanSize, ...), which defaults to 100M per file.
MAX_FILESIZE_MB=${MAX_FILESIZE_MB:-1024}
MAX_SCANSIZE_MB=${MAX_SCANSIZE_MB:-2048}
MAX_RECURSION=${MAX_RECURSION:-32}
MAX_FILES=${MAX_FILES:-20000}
USE_CLAMD=${USE_CLAMD:-1}                    # prefer the clamd daemon when reachable
DETECT_PUA=${DETECT_PUA:-1}                  # clamscan only; clamd uses DetectPUA in clamd.conf
STRICT=${STRICT:-0}                          # encrypted/broken/macro alerts (noisy)
FAST_RECENT_DAYS=${FAST_RECENT_DAYS:-60}
FAST_MAX_SIZE_MB=${FAST_MAX_SIZE_MB:-}
FAST_INCLUDE_EXTS=${FAST_INCLUDE_EXTS:-"exe dll so bin run elf msi bat cmd com scr pif cpl ps1 vbs vbe wsf wsh hta lnk reg sh py pl rb js mjs ts go php jar war ear class apk deb rpm pkg dmg appimage flatpak snap desktop tar gz xz bz2 zst zip 7z rar iso pdf doc docm docx xls xlsm xlsx ppt pptm pptx rtf html htm svg"}
SKIP_FILE_EXTS=${SKIP_FILE_EXTS:-"qcow2 vdi vmdk vhd vhdx"}
EXCLUDE_NAMES=${EXCLUDE_NAMES:-"node_modules"}
LOG_RETENTION_DAYS=${LOG_RETENTION_DAYS:-30}

CLAM_STATE="$PX_STATE_DIR/clamav"
LOG_DIR="$CLAM_STATE/logs"
HISTORY_FILE="$CLAM_STATE/history.log"
BASELINE_DIR="$CLAM_STATE/baseline"
QUARANTINE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/piercingxx/quarantine"

HOME_EXCLUDES=(
    "$HOME/.cache"
    "$HOME/.local/share/Trash"
    "$HOME/.local/share/Steam"
    "$HOME/.steam"
    "$HOME/.local/share/containers"
    "$HOME/.local/share/gnome-boxes"
    "$HOME/.local/share/libvirt"
    "$HOME/VirtualBox VMs"
    "$HOME/.cargo/registry"
    "$HOME/.rustup"
    "$HOME/.npm"
    "$HOME/go/pkg"
    "$QUARANTINE_DIR"
    "$CLAM_STATE"
)
SYSTEM_EXCLUDES=(
    /proc /sys /dev /run /tmp /var/tmp
    /var/lib/clamav
    /var/cache/pacman/pkg /var/cache/apt/archives /var/cache/dnf /var/cache/xbps /var/cache/zypp /var/cache/apk
    /var/lib/docker /var/lib/containers
    /.snapshots /timeshift /lost+found
)

NONINTERACTIVE=0
AUTO_MOVE=0
SCANNER_READY=0
SCAN_BIN=""
SCAN_OPTS=()
SCAN_PID=""
FIND_PID=""
LAST_LOG=""
WORK_DIR=""

HAS_GUM=0
command_exists gum && [ -t 1 ] && HAS_GUM=1

PRIO=(nice -n 19)
command_exists ionice && PRIO+=(ionice -c3)

# GNU find has -readable (skips files clamd can't be handed); busybox doesn't
FIND_READABLE=()
find / -maxdepth 0 -readable >/dev/null 2>&1 && FIND_READABLE=(-readable)
FIND_GNU=0
find --version 2>/dev/null | grep -q GNU && FIND_GNU=1

# --alert-exceeds-max reports oversized files as FOUND; they are skips, not infections
LIMIT_RE='Heuristics\.Limits\.Exceeded'

#########################################################
# Housekeeping
#########################################################
cleanup() {
    [ -n "$SCAN_PID" ] && kill "$SCAN_PID" 2>/dev/null
    [ -n "$FIND_PID" ] && kill "$FIND_PID" 2>/dev/null
    [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"
}
trap cleanup EXIT
trap 'echo; warn "Interrupted."; exit 130' INT TERM

init_dirs() {
    mkdir -p "$LOG_DIR" "$BASELINE_DIR" "$QUARANTINE_DIR"
    chmod 700 "$CLAM_STATE" "$QUARANTINE_DIR" 2>/dev/null
    WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/px-virus-scan.XXXXXX") || die "Could not create a temp dir."
    find "$LOG_DIR" -type f -name '*.log' -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null
}

#########################################################
# UI helpers (gum when present, plain text otherwise)
#########################################################
ui_title() {
    if [ "$HAS_GUM" = 1 ]; then
        gum style --border rounded --padding "0 2" --foreground 6 --bold "$*"
    else
        printf '\n== %s ==\n' "$*"
    fi
}
ui_ok() {
    if [ "$HAS_GUM" = 1 ]; then gum style --foreground 2 "✓ $*"; else ok "✓ $*"; fi
}
ui_warn() {
    if [ "$HAS_GUM" = 1 ]; then gum style --foreground 3 "⚠ $*"; else warn "⚠ $*"; fi
}
ui_err() {
    if [ "$HAS_GUM" = 1 ]; then gum style --foreground 1 --bold "✗ $*"; else err "✗ $*"; fi
}
ui_info() {
    if [ "$HAS_GUM" = 1 ]; then gum style --foreground 6 "$*"; else printf '%s\n' "$*"; fi
}
ui_choose() {
    local header="$1"; shift
    if [ "$HAS_GUM" = 1 ]; then
        gum choose --header "$header" "$@"
    else
        local PS3="$header> " opt
        select opt in "$@"; do
            [ -n "$opt" ] && { printf '%s\n' "$opt"; return 0; }
        done
        return 1
    fi
}
ui_pager() {
    if [ "$HAS_GUM" = 1 ]; then gum pager < "$1"; else "${PAGER:-less}" "$1"; fi
}

# need_sudo "why" : get credentials once, visibly, outside any spinner
need_sudo() {
    sudo -n true 2>/dev/null && return 0
    if [ "$NONINTERACTIVE" = 1 ] || [ ! -t 0 ]; then
        warn "sudo needs a password and there is no terminal; skipping: $1"
        return 1
    fi
    say "Administrator access needed to $1."
    sudo -v
}

# unit_exists handles systemd templates (clamd@scan) that svc_exists can't
unit_exists() {
    if [ "$INIT" = systemd ]; then
        systemctl cat "$1" >/dev/null 2>&1
    else
        svc_exists "$1"
    fi
}

#########################################################
# ClamAV install / signatures / daemon
#########################################################
clamd_units() {
    case "$INIT" in
        systemd)
            case "$DISTRO" in
                fedora) echo "clamd@scan" ;;
                suse)   echo "clamd" ;;
                *)      echo "clamav-daemon.socket clamav-daemon clamd" ;;
            esac ;;
        *) echo "clamd clamav-daemon" ;;
    esac
}

freshclam_units() {
    case "$INIT" in
        systemd) echo "clamav-freshclam freshclam" ;;
        *)       echo "freshclam clamav-freshclam" ;;
    esac
}

first_unit() {
    local u
    for u in "$@"; do
        unit_exists "$u" && { echo "$u"; return 0; }
    done
    return 1
}

db_dir() {
    if [ -n "${CLAMAV_DB_DIR:-}" ]; then echo "$CLAMAV_DB_DIR"; return; fi
    local c d
    for c in /etc/clamav/freshclam.conf /etc/freshclam.conf; do
        [ -r "$c" ] || continue
        d=$(awk '$1=="DatabaseDirectory"{print $2; exit}' "$c")
        [ -n "$d" ] && { echo "$d"; return; }
    done
    echo /var/lib/clamav
}

clamd_conf() {
    local c
    for c in /etc/clamav/clamd.conf /etc/clamd.d/scan.conf /etc/clamd.conf; do
        [ -r "$c" ] && { echo "$c"; return 0; }
    done
    return 1
}

db_present() {
    local d; d=$(db_dir)
    compgen -G "$d/main.c[vl]d" >/dev/null && compgen -G "$d/daily.c[vl]d" >/dev/null
}

# Hours since the daily database last changed (99999 if missing)
db_age_hours() {
    local d f newest=0 m
    d=$(db_dir)
    for f in "$d"/daily.cvd "$d"/daily.cld; do
        [ -f "$f" ] || continue
        m=$(stat -c %Y "$f" 2>/dev/null) || continue
        [ "$m" -gt "$newest" ] && newest=$m
    done
    if [ "$newest" -eq 0 ]; then echo 99999; else echo $(( ($(date +%s) - newest) / 3600 )); fi
}

install_clamav() {
    command_exists clamscan && return 0
    if [ "$NONINTERACTIVE" = 1 ]; then
        err "ClamAV is not installed."
        return 1
    fi
    confirm "ClamAV is not installed. Install it now?" || return 1
    need_sudo "install ClamAV" || return 1
    case "$DISTRO" in
        arch)   pkg_install clamav ;;
        artix)
            pkg_install clamav || return 1
            pkg_install "clamav-$INIT" 2>/dev/null || true ;;
        debian) sudo apt-get update && pkg_install clamav clamav-daemon clamav-freshclam ;;
        fedora) pkg_install clamav clamav-update clamd ;;
        suse|void|alpine) pkg_install clamav ;;
        *)      err "Don't know how to install ClamAV on this distro."; return 1 ;;
    esac || { ui_err "ClamAV install failed."; return 1; }
    ui_ok "ClamAV installed."
    offer_services
}

# After install: offer automatic updates and the daemon (never forced)
offer_services() {
    local fc cd
    fc=$(first_unit $(freshclam_units)) || fc=""
    if [ -n "$fc" ] && ! svc_is_active "$fc"; then
        if confirm "Enable automatic signature updates ($fc)?"; then
            need_sudo "enable $fc" && svc_enable_now "$fc"
        fi
    fi
    cd=$(first_unit $(clamd_units)) || cd=""
    if [ -n "$cd" ] && ! svc_is_active "$cd"; then
        if confirm "Enable the clamd daemon ($cd) for much faster scans? (keeps ~1 GB RAM in use)"; then
            db_present || update_definitions
            need_sudo "enable $cd" && svc_enable_now "$cd"
        fi
    fi
}

# update_definitions [force] -> 0 ok, 2 failed
# Never leaves a service running that wasn't running before.
update_definitions() {
    local force="${1:-}" fc age
    command_exists freshclam || { err "freshclam is not installed."; return 2; }
    fc=$(first_unit $(freshclam_units)) || fc=""
    age=$(db_age_hours)

    if [ -n "$fc" ] && svc_is_active "$fc"; then
        # The daemon already checks for updates on its own
        if db_present && [ "$age" -lt 24 ] && [ "$force" != force ]; then
            ui_ok "$fc is running and signatures are ${age}h old; nothing to do."
            return 0
        fi
        need_sudo "restart $fc" || return 2
        say "Restarting $fc to trigger an immediate update check..."
        if svc_stop "$fc" && svc_start "$fc"; then
            ui_ok "$fc restarted; it downloads new signatures in the background."
            return 0
        fi
        ui_err "Could not restart $fc."
        return 2
    fi

    need_sudo "update virus signatures" || return 2
    say "Updating virus signatures..."
    if [ "$INIT" = systemd ] && unit_exists clamav-freshclam-once.service; then
        # Arch ships a oneshot unit that runs freshclam once and exits
        if sudo systemctl start clamav-freshclam-once.service; then
            ui_ok "Virus signatures updated."
            return 0
        fi
        ui_err "clamav-freshclam-once failed: journalctl -u clamav-freshclam-once"
        return 2
    fi

    local out="$WORK_DIR/freshclam.out"
    if sudo freshclam 2>&1 | tee "$out"; then
        ui_ok "Virus signatures updated."
        return 0
    fi
    if grep -qi 'lock' "$out"; then
        ui_err "Another freshclam is holding the database lock. Try again in a minute."
    else
        ui_err "freshclam failed; scanning will use the existing signatures."
    fi
    return 2
}

# Signatures must exist before clamd will even start
ensure_db() {
    if ! db_present; then
        ui_warn "No virus signature database yet; downloading it now (first run, ~300 MB)."
        update_definitions
        db_present || { ui_err "No signature database available. Run: freshclam"; return 1; }
    fi
    local age; age=$(db_age_hours)
    if [ "$age" -gt 72 ]; then
        ui_warn "Signatures are $((age / 24)) days old."
        if [ "$NONINTERACTIVE" = 1 ]; then
            update_definitions || true
        elif confirm "Update them before scanning?"; then
            update_definitions || true
        fi
    fi
    return 0
}

# Make sure clamd answers; start it via the init system if the user agrees
ensure_clamd() {
    command_exists clamdscan || return 1
    clamdscan --ping=1 >/dev/null 2>&1 && return 0

    # Socket-activated clamd is "running" but still loading signatures
    if [ "$INIT" = systemd ] && systemctl is-active --quiet clamav-daemon.socket 2>/dev/null; then
        say "Waiting for clamd to load signatures (can take up to a minute)..."
        clamdscan --ping=90:1 >/dev/null 2>&1 && return 0
    fi

    local unit; unit=$(first_unit $(clamd_units)) || return 1
    if [ "$NONINTERACTIVE" = 1 ]; then
        sudo -n true 2>/dev/null || return 1
    else
        confirm "clamd isn't running. Start $unit for faster scans? (keeps ~1 GB RAM in use)" || return 1
        need_sudo "start $unit" || return 1
    fi
    svc_start "$unit" >/dev/null 2>&1 || return 1
    say "Waiting for clamd to load signatures (can take up to a minute)..."
    clamdscan --ping=90:1 >/dev/null 2>&1
}

select_scanner() {
    [ "$SCANNER_READY" = 1 ] && return 0
    if [ "$USE_CLAMD" = 1 ] && ensure_clamd; then
        SCAN_BIN="clamdscan"
        local pass="--fdpass" conf
        # --fdpass needs a LocalSocket; TCP-only setups have to stream
        if conf=$(clamd_conf) && ! grep -qE '^[[:space:]]*LocalSocket[[:space:]]' "$conf" \
            && grep -qE '^[[:space:]]*TCPSocket[[:space:]]' "$conf"; then
            pass="--stream"
        fi
        SCAN_OPTS=(--multiscan "$pass")
    else
        SCAN_BIN="clamscan"
        SCAN_OPTS=(
            --max-filesize="${MAX_FILESIZE_MB}M"
            --max-scansize="${MAX_SCANSIZE_MB}M"
            --max-recursion="$MAX_RECURSION"
            --max-files="$MAX_FILES"
            --alert-exceeds-max=yes
            --cross-fs=no
            --follow-dir-symlinks=0
            --follow-file-symlinks=0
        )
        [ "$DETECT_PUA" = 1 ] && SCAN_OPTS+=(--detect-pua=yes --exclude-pua=Packed --exclude-pua=PwTool)
        [ "$STRICT" = 1 ] && SCAN_OPTS+=(--alert-encrypted-archive=yes --alert-encrypted-doc=yes --alert-broken=yes --alert-macros=yes)
        [ "$USE_CLAMD" = 1 ] && ui_warn "clamd unavailable; using clamscan (slower, loads signatures each run)."
    fi
    SCANNER_READY=1
}

clamd_limit_note() {
    [ "$SCAN_BIN" = clamdscan ] || return 0
    local conf limit="100M"
    if conf=$(clamd_conf); then
        limit=$(awk '$1=="MaxFileSize"{print $2; exit}' "$conf")
        limit=${limit:-100M}
    fi
    ui_info "clamd skips files larger than $limit (MaxFileSize in clamd.conf; USE_CLAMD=0 uses clamscan limits)."
}

#########################################################
# File lists
#########################################################
# build_find_args MODE ROOT... -> FIND_ARGS. MODE: all | fast | recent
build_find_args() {
    local mode="$1"; shift
    local roots=("$@") prune=() p r skip ext

    for p in "${SYSTEM_EXCLUDES[@]}" "${HOME_EXCLUDES[@]}"; do
        # Never prune a root the user explicitly asked to scan
        skip=0
        for r in "${roots[@]}"; do
            [[ "$r" == "$p" || "$r" == "$p"/* ]] && skip=1
        done
        [ "$skip" = 0 ] && prune+=(-path "$p" -o)
    done
    for p in $EXCLUDE_NAMES; do
        prune+=(-name "$p" -o)
    done
    prune+=(-path "$HOME/.var/app/*/cache")

    FIND_ARGS=("${roots[@]}" -xdev '(' -type d '(' "${prune[@]}" ')' ')' -prune -o -type f "${FIND_READABLE[@]}")
    for ext in $SKIP_FILE_EXTS; do
        FIND_ARGS+=(! -iname "*.$ext")
    done
    case "$mode" in
        fast)
            local sel=(-perm /111 -o -mtime "-$FAST_RECENT_DAYS")
            for ext in $FAST_INCLUDE_EXTS; do
                sel+=(-o -iname "*.${ext#.}")
            done
            FIND_ARGS+=('(' "${sel[@]}" ')')
            ;;
        recent)
            FIND_ARGS+=(-mtime "-$FAST_RECENT_DAYS")
            ;;
    esac
    # -size -NM rounds up to whole MiB, so compare in KiB
    [ "$mode" = fast ] && [ -n "$FAST_MAX_SIZE_MB" ] && FIND_ARGS+=(-size "-$((FAST_MAX_SIZE_MB * 1024 + 1))k")
    # --file-list is newline separated, so names containing a newline go to a
    # NUL-separated side list (GNU find) and are scanned separately
    if [ "$FIND_GNU" = 1 ]; then
        FIND_ARGS+=('(' '(' -name $'*\n*' -fprint0 "$NL_LIST" ')' -o -print ')')
    else
        FIND_ARGS+=(! -name $'*\n*' -print)
    fi
}

# gather_list LIST_FILE MODE ROOT... : run find in the background with a live count
gather_list() {
    local list="$1"; shift
    NL_LIST="$list.nl"
    : > "$NL_LIST"
    build_find_args "$@"
    find "${FIND_ARGS[@]}" 2>/dev/null > "$list" &
    FIND_PID=$!
    while kill -0 "$FIND_PID" 2>/dev/null; do
        [ -t 1 ] && printf '\r  Gathering files... %s' "$(wc -l < "$list")"
        sleep 1
    done
    wait "$FIND_PID" 2>/dev/null
    FIND_PID=""
    [ -t 1 ] && printf '\r\033[K'
}

# found_lines FILE : real detections only (no size-limit skips)
found_lines() {
    grep ' FOUND$' "$1" | grep -v "$LIMIT_RE"
}

#########################################################
# Scanning
#########################################################
# run_scan PRESET LIST_FILE -> 0 clean, 1 infected, 2 errors
run_scan() {
    local preset="$1" list="$2"
    local total raw log start rc infected errors skipped scanned shown=0 elapsed nl_count=0

    total=$(wc -l < "$list")
    [ -s "${NL_LIST:-}" ] && nl_count=$(tr -cd '\0' < "$NL_LIST" | wc -c)
    total=$((total + nl_count))
    if [ "$total" -eq 0 ]; then
        ui_warn "No files to scan."
        return 0
    fi

    raw="$WORK_DIR/raw.out"
    log="$LOG_DIR/scan-$preset-$(date +%Y%m%d-%H%M%S).log"
    LAST_LOG="$log"
    : > "$raw"
    clamd_limit_note
    ui_info "Scanning $total files with $SCAN_BIN (Ctrl-C to stop)..."

    start=$(date +%s)
    "${PRIO[@]}" "$SCAN_BIN" "${SCAN_OPTS[@]}" --file-list="$list" > "$raw" 2>&1 &
    SCAN_PID=$!

    while kill -0 "$SCAN_PID" 2>/dev/null; do
        local found_now
        found_now=$(found_lines "$raw" | wc -l)
        if [ "$found_now" -gt "$shown" ]; then
            [ -t 1 ] && printf '\r\033[K'
            found_lines "$raw" | sed -n "$((shown + 1)),${found_now}p" | while IFS= read -r line; do
                printf '%s\n' "${RED}${line}${NC}"
            done
            shown=$found_now
        fi
        if [ -t 1 ]; then
            scanned=$(wc -l < "$raw")
            [ "$scanned" -gt "$total" ] && scanned=$total
            elapsed=$(( $(date +%s) - start ))
            printf '\r  Scanned %s/%s (%s%%) · FOUND %s · %ss ' \
                "$scanned" "$total" "$(( scanned * 100 / total ))" "$shown" "$elapsed"
        fi
        sleep 2
    done
    wait "$SCAN_PID"
    rc=$?
    SCAN_PID=""
    [ -t 1 ] && printf '\r\033[K'

    # Names with embedded newlines can't go through --file-list
    if [ "$nl_count" -gt 0 ]; then
        xargs -0 -r "${PRIO[@]}" "$SCAN_BIN" "${SCAN_OPTS[@]}" < "$NL_LIST" >> "$raw" 2>&1
        local nl_rc=$?
        [ "$nl_rc" -gt "$rc" ] && [ "$nl_rc" -lt 123 ] && rc=$nl_rc
    fi
    elapsed=$(( $(date +%s) - start ))

    infected=$(found_lines "$raw" | wc -l)
    skipped=$(grep ' FOUND$' "$raw" | grep -c "$LIMIT_RE")
    errors=$(grep -cE ' ERROR$|^ERROR:|^LibClamAV Error' "$raw")
    {
        printf '# preset=%s scanner=%s files=%s date=%s duration=%ss exit=%s\n' \
            "$preset" "$SCAN_BIN" "$total" "$(date '+%F %T')" "$elapsed" "$rc"
        grep -vE ': (OK|Empty file)$' "$raw"
    } > "$log"

    # Leftover FOUND lines that arrived after the last poll
    if [ "$infected" -gt "$shown" ]; then
        found_lines "$raw" | sed -n "$((shown + 1)),\$p" | while IFS= read -r line; do
            printf '%s\n' "${RED}${line}${NC}"
        done
    fi

    local result=0
    if [ "$infected" -gt 0 ]; then
        result=1
    elif [ "$rc" -ge 2 ] || [ "$errors" -gt 0 ]; then
        result=2
    fi

    printf '%s|%s|%s|%s|%s|%s|%s|%ss|%s\n' "$(date '+%F %T')" "$preset" "$SCAN_BIN" \
        "$total" "$infected" "$errors" "$skipped" "$elapsed" "$log" >> "$HISTORY_FILE"

    echo
    printf '  %-10s %s\n' "Scanned" "$total" "Infected" "$infected" "Errors" "$errors" \
        "Too large" "$skipped (not scanned)" "Duration" "${elapsed}s" "Log" "$log"
    echo
    case "$result" in
        0) ui_ok "No threats found." ;;
        1) ui_err "$infected infected file(s) found!" ;;
        2) ui_warn "Scan finished with $errors error(s); see the log." ;;
    esac

    if [ "$result" = 1 ]; then
        notify_replace virus-scan critical 0 dialog-warning \
            "ClamAV: $infected infected file(s)" "Preset $preset · $log"
        offer_quarantine "$log"
    elif [ "$NONINTERACTIVE" = 1 ] || [ "$elapsed" -gt 120 ]; then
        notify_replace virus-scan low 6000 security-high \
            "ClamAV: $preset scan finished" "$total files · $errors errors"
    fi
    return "$result"
}

# scan_preset NAME [PATH] -> scan result code
scan_preset() {
    local preset="$1" path="${2:-}" list roots=() mode=all

    case "$preset" in
        fast)
            ui_title "Fast Targeted Scan - executables, scripts, archives, documents, recent files"
            roots=("$HOME"); mode=fast ;;
        downloads)
            ui_title "Recent Downloads Scan (last $FAST_RECENT_DAYS days)"
            [ -d "$HOME/Downloads" ] || { ui_warn "No Downloads directory found."; return 0; }
            roots=("$HOME/Downloads"); mode=recent ;;
        quick)
            ui_title "Quick Scan - common user and temp directories"
            local d
            for d in "$HOME/Downloads" "$HOME/Documents" "$HOME/Desktop" "$HOME/.local/share" \
                     "$HOME/.local/bin" "$HOME/bin" "$HOME/.config/autostart" /tmp /var/tmp /dev/shm; do
                [ -d "$d" ] && roots+=("$d")
            done ;;
        full)
            ui_title "Full Home Directory Scan"
            ui_info "Stays on the home filesystem; other drives and network mounts are skipped."
            roots=("$HOME") ;;
        custom)
            [ -n "$path" ] || { ui_err "custom needs a path."; return 2; }
            path=$(realpath -m "$path" 2>/dev/null || readlink -f "$path" 2>/dev/null || printf '%s' "$path")
            [ -e "$path" ] || { ui_err "Path does not exist: $path"; return 2; }
            ui_title "Scanning: $path"
            roots=("$path") ;;
        *)
            ui_err "Unknown preset: $preset (fast|downloads|quick|full|custom PATH)"
            return 2 ;;
    esac

    ensure_db || return 2
    select_scanner

    list="$WORK_DIR/files.list"
    if [ "$preset" = custom ] && [ -f "$path" ]; then
        NL_LIST=""
        printf '%s\n' "$path" > "$list"
    else
        gather_list "$list" "$mode" "${roots[@]}"
    fi
    run_scan "$preset" "$list"
}

#########################################################
# Quarantine
#########################################################
# Parse "path: Signature FOUND" lines from a log into path<TAB>sig
found_entries() {
    found_lines "$1" | while IFS= read -r line; do
        line="${line% FOUND}"
        printf '%s\t%s\n' "${line%: *}" "${line##*: }"
    done
}

quarantine_file() {
    local path="$1" sig="$2" id sha mode
    [ -f "$path" ] || { ui_warn "Already gone: $path"; return 1; }
    if [ ! -w "$(dirname "$path")" ]; then
        ui_warn "No permission to move $path (owner: $(stat -c %U "$path")). Remove it as that user."
        return 1
    fi
    id="$(date +%Y%m%d-%H%M%S)-$$-$RANDOM"
    sha=$(sha256sum "$path" | cut -d' ' -f1)
    mode=$(stat -c %a "$path")
    mv -- "$path" "$QUARANTINE_DIR/$id.quar" || return 1
    chmod 0400 "$QUARANTINE_DIR/$id.quar"
    printf 'path=%s\nsignature=%s\nsha256=%s\nmode=%s\ndate=%s\n' \
        "$path" "$sig" "$sha" "$mode" "$(date '+%F %T')" > "$QUARANTINE_DIR/$id.meta"
    ui_ok "Quarantined: $path"
}

# Report-only by default; moving needs a yes (or --move)
offer_quarantine() {
    local log="$1" entries
    entries="$WORK_DIR/found.tsv"
    found_entries "$log" > "$entries"
    [ -s "$entries" ] || return 0

    if [ "$AUTO_MOVE" != 1 ]; then
        [ "$NONINTERACTIVE" = 1 ] && return 0
        confirm "Move the infected file(s) to quarantine ($QUARANTINE_DIR)?" || return 0
    fi
    local path sig
    while IFS=$'\t' read -r path sig; do
        quarantine_file "$path" "$sig"
    done < "$entries"
}

meta_get() { sed -n "s/^$2=//p" "$1" | head -n 1; }

quarantine_menu() {
    while true; do
        clear
        ui_title "Quarantine ($QUARANTINE_DIR)"
        local metas=() labels=() m
        for m in "$QUARANTINE_DIR"/*.meta; do
            [ -f "$m" ] || continue
            metas+=("$m")
            labels+=("$(meta_get "$m" date) · $(meta_get "$m" signature) · $(meta_get "$m" path)")
        done
        if [ ${#metas[@]} -eq 0 ]; then
            ui_ok "Quarantine is empty."
            pause
            return
        fi
        local choice
        choice=$(ui_choose "Pick a file" "${labels[@]}" "Delete ALL quarantined files" "Back") || return
        case "$choice" in
            "Back"|"") return ;;
            "Delete ALL quarantined files")
                confirm "Permanently delete all ${#metas[@]} quarantined file(s)?" || continue
                rm -f "$QUARANTINE_DIR"/*.quar "$QUARANTINE_DIR"/*.meta
                ui_ok "Quarantine emptied."
                pause
                continue ;;
        esac
        local i sel=""
        for i in "${!labels[@]}"; do
            [ "${labels[$i]}" = "$choice" ] && sel="${metas[$i]}"
        done
        [ -n "$sel" ] && quarantine_item_menu "$sel"
    done
}

quarantine_item_menu() {
    local meta="$1" quar="${1%.meta}.quar"
    local path sig sha
    path=$(meta_get "$meta" path)
    sig=$(meta_get "$meta" signature)
    sha=$(meta_get "$meta" sha256)
    ui_info "File:      $path"
    ui_info "Signature: $sig"
    ui_info "SHA256:    $sha"
    local action
    action=$(ui_choose "Action" "Rescan" "Restore to original location" "Delete permanently" "Show VirusTotal link (hash only)" "Back") || return
    case "$action" in
        "Rescan")
            select_scanner
            chmod 0600 "$quar"
            "$SCAN_BIN" "${SCAN_OPTS[@]}" "$quar"
            chmod 0400 "$quar"
            pause ;;
        "Restore to original location")
            ui_warn "This file was detected as $sig."
            confirm "Restore it to $path anyway?" || return
            if [ -e "$path" ]; then
                confirm "$path exists. Overwrite it?" || return
            fi
            mkdir -p "$(dirname "$path")" &&
                mv -- "$quar" "$path" &&
                chmod "$(meta_get "$meta" mode)" "$path" &&
                rm -f "$meta" &&
                ui_ok "Restored $path"
            pause ;;
        "Delete permanently")
            confirm "Delete $path from quarantine for good?" || return
            rm -f "$quar" "$meta"
            ui_ok "Deleted."
            pause ;;
        "Show VirusTotal link (hash only)")
            ui_info "https://www.virustotal.com/gui/file/$sha"
            ui_info "(Nothing is uploaded; this only looks up the hash.)"
            pause ;;
    esac
}

#########################################################
# Status, logs, history
#########################################################
show_status() {
    ui_title "ClamAV Status"
    if ! command_exists clamscan; then
        ui_err "ClamAV is not installed."
        return
    fi
    local d age fc cd tmpdirs qcount last
    d=$(db_dir)
    age=$(db_age_hours)
    printf '  %-22s %s\n' "Engine / signatures" "$(clamscan --version 2>/dev/null)"
    if db_present; then
        printf '  %-22s %s\n' "Signature age" "${age}h ($d)"
        [ "$age" -gt 72 ] && ui_warn "Signatures are more than 3 days old."
    else
        ui_err "No signature database in $d (run Update Virus Definitions)."
    fi
    fc=$(first_unit $(freshclam_units)) || fc=""
    if [ -n "$fc" ]; then
        if svc_is_active "$fc"; then
            printf '  %-22s %s\n' "Auto updates" "$fc running"
        elif [ "$INIT" = systemd ] && systemctl is-enabled --quiet clamav-freshclam-once.timer 2>/dev/null; then
            printf '  %-22s %s\n' "Auto updates" "clamav-freshclam-once.timer enabled"
        else
            printf '  %-22s %s\n' "Auto updates" "off ($fc not running)"
        fi
    fi
    if command_exists clamdscan && clamdscan --ping=1 >/dev/null 2>&1; then
        printf '  %-22s %s\n' "clamd" "running (fast scans)"
    else
        cd=$(first_unit $(clamd_units)) || cd="none found"
        printf '  %-22s %s\n' "clamd" "not running (unit: $cd)"
    fi
    tmpdirs=$(find "$d" -maxdepth 1 -type d -name 'tmp.*' 2>/dev/null | wc -l)
    [ "$tmpdirs" -gt 0 ] && printf '  %-22s %s\n' "Stale freshclam temp" "$tmpdirs dir(s) in $d (from interrupted updates)"
    qcount=$(find "$QUARANTINE_DIR" -maxdepth 1 -name '*.quar' 2>/dev/null | wc -l)
    printf '  %-22s %s\n' "Quarantined files" "$qcount"
    if [ -f "$HISTORY_FILE" ]; then
        last=$(tail -n 1 "$HISTORY_FILE" | awk -F'|' '{printf "%s  %s  %s files, %s infected, %s errors", $1, $2, $4, $5, $6}')
        printf '  %-22s %s\n' "Last scan" "$last"
    fi
    if [ "$INIT" = systemd ]; then
        printf '  %-22s %s\n' "Scheduled scan" "$(timer_state)"
    fi
    printf '  %-22s %s\n' "Strict heuristics" "$([ "$STRICT" = 1 ] && echo on || echo off) (clamscan only)"
}

logs_menu() {
    local logs=() labels=() f choice
    while IFS= read -r f; do
        logs+=("$f")
        labels+=("$(basename "$f")")
    done < <(ls -1t "$LOG_DIR"/*.log 2>/dev/null | head -n 30)
    choice=$(ui_choose "Logs" "Scan history" "${labels[@]}" "Back") || return
    case "$choice" in
        "Back"|"") return ;;
        "Scan history")
            if [ ! -s "$HISTORY_FILE" ]; then
                ui_warn "No scans recorded yet."
                pause
                return
            fi
            {
                echo "date|preset|scanner|files|infected|errors|too-large|duration|log"
                tail -n 20 "$HISTORY_FILE"
            } | column -t -s '|' > "$WORK_DIR/history.txt"
            ui_pager "$WORK_DIR/history.txt" ;;
        *)
            ui_pager "$LOG_DIR/$choice" ;;
    esac
}

#########################################################
# System integrity audit
#########################################################
audit_tools_for_distro() {
    case "$DISTRO" in
        arch|artix) echo "rkhunter lynis arch-audit unhide" ;;
        debian)     echo "rkhunter chkrootkit lynis unhide debsums" ;;
        fedora)     echo "rkhunter chkrootkit lynis unhide" ;;
        *)          echo "rkhunter chkrootkit lynis" ;;
    esac
}

install_audit_tools() {
    local missing=() t
    for t in $(audit_tools_for_distro); do
        command_exists "$t" || missing+=("$t")
    done
    local aur; aur=$(aur_helper)
    if is_arch_like && ! command_exists chkrootkit && [ -n "$aur" ]; then
        missing+=("chkrootkit(AUR)")
    fi
    [ ${#missing[@]} -eq 0 ] && return 0
    confirm "Install missing audit tools: ${missing[*]}?" || return 0
    need_sudo "install audit tools" || return 0
    [ "$DISTRO" = debian ] && sudo apt-get update
    for t in "${missing[@]}"; do
        if [ "$t" = "chkrootkit(AUR)" ]; then
            "$aur" -S --needed chkrootkit || warn "chkrootkit install failed."
        else
            pkg_install "$t" || warn "$t isn't available here; skipping."
        fi
    done
}

# baseline_diff NAME CURRENT_FILE : first run saves, later runs show changes
baseline_diff() {
    local base="$BASELINE_DIR/$1"
    cp "$2" "$WORK_DIR/current-$1"
    if [ ! -f "$base" ]; then
        cp "$2" "$base"
        echo "Baseline saved; future audits will report changes."
        return 0
    fi
    if diff "$base" "$2" > "$WORK_DIR/diff-$1"; then
        echo "No changes since baseline ($(date -r "$base" +%F))."
        return 0
    fi
    echo "CHANGES since baseline ($(date -r "$base" +%F)):  < removed   > added"
    grep -E '^[<>]' "$WORK_DIR/diff-$1"
    echo "$1" >> "$WORK_DIR/audit-changed"
    return 1
}

integrity_audit() {
    ui_title "System Integrity Audit"
    install_audit_tools
    local have_sudo=0
    need_sudo "run root-level checks (rkhunter, package verification, SUID scan)" && have_sudo=1

    local report="$LOG_DIR/audit-$(date +%Y%m%d-%H%M%S).log"
    : > "$WORK_DIR/audit-changed"
    LAST_LOG="$report"

    {
        echo "PiercingXX integrity audit · $(date '+%F %T') · $DISTRO_ID ($DISTRO)"

        echo; echo "== Package file verification =="
        if [ "$have_sudo" = 1 ]; then
            case "$DISTRO" in
                arch|artix)
                    sudo pacman -Qkk 2>&1 | grep -vE ', 0 altered files$|^warning: .*(Permission denied|Modification time mismatch)' ;;
                debian)
                    if command_exists debsums; then sudo debsums -s 2>&1; else echo "debsums not installed."; fi ;;
                fedora|suse)
                    sudo rpm -Va 2>&1 | grep -vE '^.{8,10} +c ' ;;
                alpine)
                    sudo apk audit --system 2>&1 ;;
                *)  echo "No package verification for $DISTRO." ;;
            esac
        else
            echo "Skipped (needs sudo)."
        fi

        if command_exists arch-audit; then
            echo; echo "== Installed packages with known vulnerabilities (arch-audit) =="
            arch-audit 2>&1
        fi

        if command_exists rkhunter && [ "$have_sudo" = 1 ]; then
            echo; echo "== rkhunter =="
            if ! sudo test -s /var/lib/rkhunter/db/rkhunter.dat; then
                echo "Creating rkhunter file baseline (first run)..."
                sudo rkhunter --propupd --quiet 2>&1
            fi
            sudo rkhunter --check --sk --rwo --nocolors 2>&1
        fi

        if command_exists chkrootkit && [ "$have_sudo" = 1 ]; then
            echo; echo "== chkrootkit =="
            sudo chkrootkit -q 2>&1
        fi

        if command_exists unhide && [ "$have_sudo" = 1 ]; then
            echo; echo "== Hidden processes (unhide) =="
            sudo unhide sys proc 2>&1 | grep -vE '^(Unhide|Copyright|License|NOTE|Used options)'
        fi

        if command_exists lynis && [ "$have_sudo" = 1 ]; then
            echo; echo "== Lynis warnings and suggestions =="
            sudo lynis audit system --quick --quiet --no-colors >/dev/null 2>&1
            sudo grep -E '^(hardening_index|warning\[\]|suggestion\[\])=' /var/log/lynis-report.dat 2>/dev/null \
                | sed -e 's/^warning\[\]=/WARNING: /' -e 's/^suggestion\[\]=/suggestion: /'
        fi

        echo; echo "== Preload hijacking =="
        if [ -s /etc/ld.so.preload ]; then
            echo "WARNING: /etc/ld.so.preload is not empty:"
            cat /etc/ld.so.preload
        else
            echo "/etc/ld.so.preload: empty or absent (good)."
        fi
        grep -rHs 'LD_PRELOAD' /etc/environment /etc/environment.d "$HOME/.config/environment.d" /etc/profile.d 2>/dev/null \
            || echo "No LD_PRELOAD in environment files."

        echo; echo "== Autostart and persistence =="
        echo "-- User systemd units:"
        ls -1 "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/"*.{service,timer} 2>/dev/null || echo "(none)"
        if [ "$INIT" = systemd ]; then
            echo "-- Locally created system units (not from packages):"
            find /etc/systemd/system -maxdepth 1 -type f \( -name '*.service' -o -name '*.timer' \) 2>/dev/null || true
        fi
        echo "-- Desktop autostart entries:"
        local a
        for a in "${XDG_CONFIG_HOME:-$HOME/.config}"/autostart/*.desktop; do
            [ -f "$a" ] && printf '%s: %s\n' "$(basename "$a")" "$(grep -m1 '^Exec=' "$a")"
        done
        echo "-- Cron:"
        crontab -l 2>/dev/null || echo "(no user crontab)"
        ls -1 /etc/cron.d 2>/dev/null
        echo "-- Suspicious lines in shell startup files:"
        grep -nHE '(curl|wget)[^|#]*\|[[:space:]]*(ba|z)?sh|base64[[:space:]]+(-d|--decode)|/dev/tcp/|nc[[:space:]].*-e[[:space:]]|LD_PRELOAD' \
            "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile" "$HOME/.zshrc" "$HOME/.zprofile" 2>/dev/null \
            || echo "(none)"

        echo; echo "== SSH authorized_keys =="
        local k
        : > "$WORK_DIR/keys"
        for k in "$HOME/.ssh/authorized_keys" "$HOME/.ssh/authorized_keys2"; do
            [ -f "$k" ] && sha256sum "$k" >> "$WORK_DIR/keys"
        done
        if [ "$have_sudo" = 1 ] && sudo test -f /root/.ssh/authorized_keys; then
            sudo sha256sum /root/.ssh/authorized_keys >> "$WORK_DIR/keys"
        fi
        if [ -s "$WORK_DIR/keys" ]; then
            baseline_diff authorized_keys "$WORK_DIR/keys"
        else
            echo "No authorized_keys files."
        fi

        echo; echo "== SUID/SGID binaries =="
        if [ "$have_sudo" = 1 ]; then
            sudo find / -xdev -perm /6000 -type f 2>/dev/null | sort > "$WORK_DIR/suid"
        else
            find / -xdev -perm /6000 -type f 2>/dev/null | sort > "$WORK_DIR/suid"
        fi
        baseline_diff suid "$WORK_DIR/suid"

        echo; echo "== Listening sockets =="
        if command_exists ss; then
            ss -tulnH 2>/dev/null | awk '{print $1, $5}' | sort -u > "$WORK_DIR/listen"
            baseline_diff listening "$WORK_DIR/listen"
        else
            echo "ss not available."
        fi

        echo; echo "== Browser extensions =="
        local ext_found=0 p
        if command_exists jq; then
            for p in "$HOME"/.mozilla/firefox/*/extensions.json "$HOME"/.librewolf/*/extensions.json \
                     "$HOME"/.zen/*/extensions.json "$HOME"/.floorp/*/extensions.json; do
                [ -f "$p" ] || continue
                ext_found=1
                echo "-- $p"
                jq -r '.addons[] | select(.location=="app-profile") | "\(.id)  \(.defaultLocale.name // "")"' "$p" 2>/dev/null
            done
        fi
        for p in "$HOME"/.config/{google-chrome,chromium,BraveSoftware/Brave-Browser,vivaldi,microsoft-edge}/*/Extensions; do
            [ -d "$p" ] || continue
            ext_found=1
            echo "-- $p"
            local e
            for e in "$p"/*/*/manifest.json; do
                [ -f "$e" ] || continue
                printf '%s  %s\n' "$(basename "$(dirname "$(dirname "$e")")")" \
                    "$(grep -m1 -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$e" | sed 's/.*:[[:space:]]*"//; s/"$//')"
            done
        done
        [ "$ext_found" = 0 ] && echo "No browser profiles found."
    } 2>&1 | tee "$report"

    echo
    ui_ok "Audit report: $report"
    notify_replace virus-scan normal 8000 security-high "Integrity audit finished" "$report"
    if [ -s "$WORK_DIR/audit-changed" ] && [ "$NONINTERACTIVE" != 1 ]; then
        ui_warn "Changed since baseline: $(tr '\n' ' ' < "$WORK_DIR/audit-changed")"
        if confirm "Accept the current state as the new baseline?"; then
            local n
            while IFS= read -r n; do
                cp "$WORK_DIR/current-$n" "$BASELINE_DIR/$n"
            done < "$WORK_DIR/audit-changed"
            ui_ok "Baseline updated."
        fi
    fi
}

#########################################################
# Scheduling (systemd --user timer)
#########################################################
timer_state() {
    local s
    s=$(systemctl --user is-enabled piercingxx-virus-scan.timer 2>/dev/null)
    [ "$s" = enabled ] && echo enabled || echo disabled
}

schedule_menu() {
    ui_title "Scheduled Scans"
    local cmd="$SCRIPT_PATH"
    [ -x "$HOME/.scripts/PiercingXX-Settings-Menu/virus-scan.sh" ] && cmd="$HOME/.scripts/PiercingXX-Settings-Menu/virus-scan.sh"

    if [ "$INIT" != systemd ]; then
        ui_info "Timers here use systemd user units, which this system ($INIT) doesn't have."
        ui_info "Add this line with 'crontab -e' for a weekly scan (Sunday 03:00):"
        echo "  0 3 * * 0 bash $cmd --preset fast --no-tui"
        pause
        return
    fi

    local unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    local state
    state=$(timer_state)
    ui_info "Weekly fast scan timer: $state"
    local choice
    choice=$(ui_choose "Scheduled scans" "Enable weekly fast scan (Sun 03:00)" "Disable" "Show next run" "Back") || return
    case "$choice" in
        "Enable weekly fast scan (Sun 03:00)")
            mkdir -p "$unit_dir"
            cat > "$unit_dir/piercingxx-virus-scan.service" <<EOF
[Unit]
Description=PiercingXX weekly ClamAV fast scan

[Service]
Type=oneshot
Nice=19
IOSchedulingClass=idle
ExecStart=/bin/bash "$cmd" --preset fast --no-tui
EOF
            cat > "$unit_dir/piercingxx-virus-scan.timer" <<'EOF'
[Unit]
Description=Weekly PiercingXX virus scan

[Timer]
OnCalendar=Sun *-*-* 03:00:00
Persistent=true
RandomizedDelaySec=30min

[Install]
WantedBy=timers.target
EOF
            systemctl --user daemon-reload &&
                systemctl --user enable --now piercingxx-virus-scan.timer &&
                ui_ok "Weekly scan enabled. Results land in $LOG_DIR and as a notification."
            ;;
        "Disable")
            systemctl --user disable --now piercingxx-virus-scan.timer 2>/dev/null
            ui_ok "Weekly scan disabled."
            ;;
        "Show next run")
            systemctl --user list-timers piercingxx-virus-scan.timer --no-pager
            ;;
        *) return ;;
    esac
    pause
}

#########################################################
# Extra (third-party) signatures
#########################################################
extra_signatures() {
    ui_title "Extra Signatures (optional)"
    ui_info "SaneSecurity, URLhaus and similar feeds add phishing, macro and Linux malware coverage."
    if is_arch_like && [ -n "$(aur_helper)" ]; then
        if [ -f /etc/fangfrisch/fangfrisch.conf ]; then
            ui_ok "fangfrisch is installed."
            [ "$INIT" = systemd ] && systemctl is-enabled fangfrisch.timer 2>/dev/null
            pause
            return
        fi
        confirm "Install fangfrisch from the AUR and enable its update timer?" || return
        need_sudo "set up fangfrisch" || return
        "$(aur_helper)" -S --needed python-fangfrisch || { ui_err "Install failed."; pause; return; }
        sudo -u clamav /usr/bin/fangfrisch --conf /etc/fangfrisch/fangfrisch.conf initdb \
            || ui_warn "fangfrisch initdb failed; see /etc/fangfrisch/fangfrisch.conf."
        if [ "$INIT" = systemd ]; then
            sudo systemctl enable --now fangfrisch.timer && ui_ok "fangfrisch.timer enabled."
        fi
    else
        ui_info "Install fangfrisch with your package manager or 'pipx install fangfrisch',"
        ui_info "then follow https://rseichter.github.io/fangfrisch/ to point it at $(db_dir)."
    fi
    pause
}

#########################################################
# Interactive pieces
#########################################################
custom_scan() {
    local how scan_path
    how=$(ui_choose "Custom scan" "Type a path" "Browse for a folder" "Back") || return
    case "$how" in
        "Type a path")
            if [ "$HAS_GUM" = 1 ]; then
                scan_path=$(gum input --placeholder "Path to scan (e.g. ~/Documents or /media/usb)")
            else
                read -r -e -p "Path to scan: " scan_path
            fi ;;
        "Browse for a folder")
            if [ "$HAS_GUM" = 1 ]; then
                scan_path=$(gum file --directory --all "$HOME")
            else
                read -r -e -p "Path to scan: " scan_path
            fi ;;
        *) return ;;
    esac
    [ -n "$scan_path" ] || { ui_err "No path provided."; return; }
    # Expand a leading ~ the way a shell would
    case "$scan_path" in
        "~")   scan_path="$HOME" ;;
        "~/"*) scan_path="$HOME/${scan_path#\~/}" ;;
    esac
    scan_preset custom "$scan_path"
}

file_scan() {
    local f
    if [ "$HAS_GUM" = 1 ]; then
        f=$(gum file --all "$HOME")
    else
        read -r -e -p "File to scan: " f
    fi
    [ -n "$f" ] || { ui_err "No file selected."; return; }
    [ -f "$f" ] || { ui_err "Not a file: $f"; return; }
    scan_preset custom "$f"
}

main_menu() {
    install_clamav || { pause; exit 1; }

    while true; do
        clear
        if [ "$HAS_GUM" = 1 ]; then
            gum style --border double --padding "1 2" --foreground 6 --bold "🦠 ClamAV Virus Scanner"
        else
            printf '\n== ClamAV Virus Scanner ==\n'
        fi

        local strict_label="⚙️  Strict Heuristics: off"
        [ "$STRICT" = 1 ] && strict_label="⚙️  Strict Heuristics: on"
        local choice
        choice=$(ui_choose "What now" \
            "🔄 Update Virus Definitions" \
            "⚡ Quick Scan" \
            "🚀 Fast Targeted Scan" \
            "📥 Recent Downloads Scan" \
            "🔍 Full Home Directory Scan" \
            "📁 Scan Custom Path" \
            "📄 Scan Specific File" \
            "🧪 System Integrity Audit" \
            "🗄️  Quarantine" \
            "📊 Status" \
            "⏰ Scheduled Scans" \
            "🧩 Extra Signatures" \
            "$strict_label" \
            "📋 Logs & History" \
            "🚪 Back to Main Menu") || choice=""

        case "$choice" in
            "🔄 Update Virus Definitions") update_definitions force; pause ;;
            "⚡ Quick Scan")               scan_preset quick; pause ;;
            "🚀 Fast Targeted Scan")       scan_preset fast; pause ;;
            "📥 Recent Downloads Scan")    scan_preset downloads; pause ;;
            "🔍 Full Home Directory Scan")
                confirm "Scan your entire home directory? This can take a long time." || continue
                scan_preset full; pause ;;
            "📁 Scan Custom Path")         custom_scan; pause ;;
            "📄 Scan Specific File")       file_scan; pause ;;
            "🧪 System Integrity Audit")   integrity_audit; pause ;;
            "🗄️  Quarantine")              quarantine_menu ;;
            "📊 Status")                   show_status; pause ;;
            "⏰ Scheduled Scans")           schedule_menu ;;
            "🧩 Extra Signatures")         extra_signatures ;;
            "⚙️  Strict Heuristics:"*)
                if [ "$STRICT" = 1 ]; then STRICT=0; else STRICT=1; fi
                SCANNER_READY=0
                [ "$STRICT" = 1 ] && ui_info "Strict mode alerts on encrypted archives, broken executables and macros (clamscan only)."
                pause ;;
            "📋 Logs & History")           logs_menu ;;
            "🚪 Back to Main Menu"|"")     clear; exit 0 ;;
        esac
    done
}

usage() {
    sed -n '7,14p' "$SCRIPT_PATH" | sed 's/^# \{0,1\}//'
}

#########################################################
# Entry point
#########################################################
ACTION="menu"
PRESET=""
PRESET_PATH=""
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)   usage; exit 0 ;;
        --update-db) ACTION="update-db" ;;
        --status)    ACTION="status" ;;
        --preset)
            ACTION="preset"
            PRESET="${2:-}"; shift
            if [ "$PRESET" = custom ]; then
                PRESET_PATH="${2:-}"; shift
            fi ;;
        --no-tui)    NONINTERACTIVE=1; HAS_GUM=0 ;;
        --move)      AUTO_MOVE=1 ;;
        --strict)    STRICT=1 ;;
        *) err "Unknown option: $1"; usage; exit 2 ;;
    esac
    shift
done
# Non-terminal callers (timers, other scripts) never get prompts
[ -t 0 ] || NONINTERACTIVE=1

init_dirs

case "$ACTION" in
    update-db)
        command_exists clamscan || { err "ClamAV is not installed."; exit 2; }
        update_definitions
        exit $? ;;
    status)
        show_status
        exit 0 ;;
    preset)
        install_clamav || exit 2
        scan_preset "$PRESET" "$PRESET_PATH"
        exit $? ;;
    *)
        main_menu ;;
esac
