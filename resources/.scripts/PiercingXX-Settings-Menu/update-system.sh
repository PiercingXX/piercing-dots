#!/bin/sh
# GitHub.com/PiercingXX
#
# Full system update: distro packages, AUR, firmware, flatpak, toolchains,
# editor/shell plugins, then a self-update of ~/.scripts and ~/.bashrc.
#
# Env knobs:
#   PX_NO_SELF_UPDATE=1   don't pull ~/.scripts / ~/.bashrc from GitHub
#   PX_AUR_NOCONFIRM=1    upgrade AUR packages without review prompts
#   PX_NO_SNAPSHOT=1      skip the pre-update timeshift/snapper snapshot
#   PX_GITHUB_DIR=path    folder of git repos to fast-forward
#   GITHUB_TOKEN=...      raises the GitHub API limit for the self-update

# POSIX bootstrap: this script needs bash and curl, which postmarketOS/Alpine
# don't ship by default. Install them (doas or sudo), then re-exec under bash.
# On distros that already have bash this just re-execs immediately.
if [ -z "${PX_BASH_REEXEC:-}" ]; then
    if ! command -v bash >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
        if command -v apk >/dev/null 2>&1; then
            if command -v doas >/dev/null 2>&1; then
                doas apk add bash curl
            elif command -v sudo >/dev/null 2>&1; then
                sudo apk add bash curl
            fi
        fi
    fi
    if command -v bash >/dev/null 2>&1; then
        PX_BASH_REEXEC=1
        export PX_BASH_REEXEC
        exec bash "$0" "$@"
    fi
    echo "This script requires bash, and it could not be installed automatically." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Everything below runs under bash. The body lives in main() and the last
# line is `main "$@"; exit $?`, so bash has parsed the whole file before any
# of it runs and the self-update can safely replace this file.
# ---------------------------------------------------------------------------

SCRIPT_PATH=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
GITHUB_REPO="Piercingxx/piercing-dots"
GITHUB_BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH"

# Shared helpers. An old ~/.scripts may predate lib/, so fetch it once if missing.
PX_LIB="$SCRIPT_DIR/../lib/common.sh"
if [ ! -r "$PX_LIB" ]; then
    mkdir -p "$(dirname "$PX_LIB")"
    if ! curl -fsSL "$RAW_BASE/resources/.scripts/lib/common.sh" -o "$PX_LIB"; then
        echo "Missing $PX_LIB and could not download it." >&2
        exit 1
    fi
fi
# shellcheck disable=SC1090
. "$PX_LIB"

if [[ -d "$HOME/.cargo/bin" && ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
    PATH="$HOME/.cargo/bin:$PATH"
fi
# Make sure ~/.local/bin is on PATH (static jq fallback installs there, e.g. on FuriOS)
if [[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    PATH="$HOME/.local/bin:$PATH"
fi

detect_distro

INTERACTIVE=0
[ -t 0 ] && INTERACTIVE=1

# Step results for the end-of-run table
STEP_NAMES=()
STEP_STATUS=()
REBOOT_REASONS=()
UPGRADED_PKGS=()
SKIP=3          # step return code: not applicable, don't list it
SKIPPED=4       # step return code: deliberately skipped, list it

PX_TMP_DIR=""
SUDO_KEEPALIVE_PID=""
LOG_FILE=""
START_EPOCH=$(date +%s)

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

record_step() {
    STEP_NAMES+=("$1")
    STEP_STATUS+=("$2")
}

# run_step "Label" func [args...]
run_step() {
    local label="$1" rc
    shift
    "$@"
    rc=$?
    case "$rc" in
        0)        record_step "$label" ok ;;
        "$SKIP")  ;;
        "$SKIPPED") record_step "$label" skipped ;;
        *)        record_step "$label" failed ;;
    esac
    return "$rc"
}

# Run a command on the real terminal (pagers, editors, AUR review prompts)
on_tty() {
    "$@" </dev/tty >/dev/tty 2>/dev/tty
}

# ask_yes "Question?" Y|N  -> non-interactive runs take the default
ask_yes() {
    local q="$1" def="${2:-N}" reply hint="[y/N]"
    [ "$def" = Y ] && hint="[Y/n]"
    if [ "$INTERACTIVE" -ne 1 ]; then
        [ "$def" = Y ]
        return
    fi
    read -r -p "$q $hint " reply </dev/tty
    reply=${reply:-$def}
    [[ "$reply" =~ ^[Yy] ]]
}

cleanup() {
    [ -n "$SUDO_KEEPALIVE_PID" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
    [ -n "$PX_TMP_DIR" ] && rm -rf "$PX_TMP_DIR"
}

# Reliable-ish internet check
check_internet() {
    local timeout=4 url code body host
    if command_exists nm-online; then
        nm-online -q -t "$timeout" && return 0
    fi
    if command_exists networkctl; then
        networkctl -q is-online --timeout="$timeout" 2>/dev/null && return 0
    fi
    local urls=(
        "https://connectivitycheck.gstatic.com/generate_204"
        "http://www.google.com/generate_204"
        "http://www.msftncsi.com/ncsi.txt"
        "http://www.msftconnecttest.com/connecttest.txt"
    )
    for url in "${urls[@]}"; do
        code=$(curl -4 -fsS --max-time "$timeout" -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || true)
        if [[ "$code" == "204" ]]; then
            return 0
        fi
        if [[ "$code" == "200" && "$url" == *"msft"* ]]; then
            body=$(curl -4 -fsS --max-time "$timeout" "$url" 2>/dev/null | tr -d '\r\n')
            if [[ "$body" == "Microsoft NCSI" || "$body" == "Microsoft Connect Test" ]]; then
                return 0
            fi
        fi
    done
    for host in 1.1.1.1 8.8.8.8 9.9.9.9; do
        if ping -4 -c 1 -W 1 "$host" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

# Ubuntu Touch: system partition is read-only; system updates are OTA, not apt
is_ubuntu_touch() {
    [[ "$DISTRO_ID" == "ubports" || "$DISTRO_ID" == "ubuntutouch" || "$DISTRO_ID" == "ubuntu-touch" ]] && return 0
    grep -qi "ubuntu touch" /etc/os-release 2>/dev/null && return 0
    command_exists system-image-cli && return 0
    [ -d /etc/system-image ] && return 0
    return 1
}

# Fallback for distros whose repos lack jq (e.g. FuriOS): official static binary, no build needed
install_jq_static() {
    local arch bin_url dest_dir tmp_bin
    case "$(uname -m)" in
        x86_64)        arch="amd64" ;;
        aarch64)       arch="arm64" ;;
        armv7l|armv6l) arch="armhf" ;;
        i386|i686)     arch="i386" ;;
        riscv64)       arch="riscv64" ;;
        *) return 1 ;;
    esac
    bin_url="https://github.com/jqlang/jq/releases/latest/download/jq-linux-${arch}"
    dest_dir="$HOME/.local/bin"
    mkdir -p "$dest_dir"
    tmp_bin=$(mktemp)
    say "jq not available from the package manager; downloading static jq binary (${arch})..."
    if curl -fsSL "$bin_url" -o "$tmp_bin" && chmod +x "$tmp_bin" && "$tmp_bin" --version >/dev/null 2>&1; then
        mv "$tmp_bin" "$dest_dir/jq"
        if [[ ":$PATH:" != *":$dest_dir:"* ]]; then
            PATH="$dest_dir:$PATH"
        fi
        return 0
    fi
    rm -f "$tmp_bin"
    return 1
}

# jq is only needed for the scripts self-update; installs from the (already
# refreshed) repos, never with `pacman -Sy`
ensure_jq() {
    command_exists jq && return 0
    say "jq is required for the scripts self-update. Installing..."
    [ "$PKG" = apt ] && sudo apt-get update -qq
    if pkg_install jq >/dev/null 2>&1 && command_exists jq; then
        return 0
    fi
    install_jq_static && return 0
    warn "Could not install jq; skipping the ~/.scripts self-update."
    return 1
}

# ---------------------------------------------------------------------------
# Self-update: ~/.scripts and ~/.bashrc from GitHub (runs last)
# ---------------------------------------------------------------------------

prune_backups() {
    local pattern="$1" keep="${2:-5}"
    find "$PX_STATE_DIR/backups" -mindepth 1 -maxdepth 1 -type d -name "$pattern" -printf '%f\n' 2>/dev/null \
        | sort -r | tail -n +$((keep + 1)) \
        | while read -r old; do rm -rf "${PX_STATE_DIR:?}/backups/$old"; done
}

# Older launch-*.sh kept the host in a REMOTE= line; hosts now live in
# ~/.config/piercingxx/remotes.conf. Carry a customized value over once.
migrate_remote_line() {
    local rel="$1" saved="$2" key value conf
    [ -n "$saved" ] || return 0
    case "$rel" in
        Control-Scripts/launch-skippy-remote.sh) key="SKIPPY_HOST" ;;
        Control-Scripts/launch-server-monitor.sh|Control-Scripts/launch-ollama-remote.sh) key="SERVER_HOST" ;;
        *) return 0 ;;
    esac
    value=$(printf '%s' "${saved#REMOTE=}" | tr -d '"'"'")
    [ -n "$value" ] || return 0
    conf="${XDG_CONFIG_HOME:-$HOME/.config}/piercingxx/remotes.conf"
    if [ -f "$conf" ] && grep -q "^$key=" "$conf"; then
        return 0
    fi
    mkdir -p "$(dirname "$conf")"
    printf '%s="%s"\n' "$key" "$value" >> "$conf"
    say "Moved $key=$value from $rel into $conf"
}

sync_scripts() {
    local backup="$1"
    local prefix="resources/.scripts/"
    local local_root="$HOME/.scripts"
    local tree="$PX_TMP_DIR/tree.json"
    local code

    if [ -L "$local_root" ]; then
        say "~/.scripts is a symlink (dev checkout); not overwriting it."
        return "$SKIPPED"
    fi

    local -a auth=()
    [ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
    # One API call for the whole tree; files then come from raw.githubusercontent.com
    code=$(curl -sS --max-time 30 -o "$tree" -w '%{http_code}' \
        -H 'Accept: application/vnd.github+json' "${auth[@]}" \
        "https://api.github.com/repos/$GITHUB_REPO/git/trees/$GITHUB_BRANCH?recursive=1" 2>/dev/null) || code="000"
    case "$code" in
        200) ;;
        403|429)
            warn "GitHub API rate limit reached; skipping the scripts self-update. (Set GITHUB_TOKEN to raise the limit.)"
            return 1 ;;
        *)
            warn "GitHub API returned HTTP $code; skipping the scripts self-update."
            return 1 ;;
    esac
    if ! jq -e '.tree | type == "array"' "$tree" >/dev/null 2>&1; then
        warn "Unexpected GitHub API response; skipping the scripts self-update."
        return 1
    fi
    [ "$(jq -r '.truncated' "$tree")" = true ] && warn "GitHub returned a truncated file tree; some scripts may be skipped."

    mkdir -p "$local_root"
    local updated=0 failed=0 path sha mode rel target new saved_remote
    while IFS=$'\t' read -r path sha mode; do
        rel="${path#"$prefix"}"
        target="$local_root/$rel"

        if [ -L "$target" ]; then
            continue
        fi
        # Unchanged files: compare git blob hashes, no download needed
        if [ -f "$target" ] && command_exists git \
            && [ "$(git hash-object "$target" 2>/dev/null)" = "$sha" ]; then
            rm -f "$target.upstream"
            continue
        fi

        saved_remote=""
        if [[ "$rel" == Control-Scripts/launch-*.sh && -f "$target" ]]; then
            saved_remote=$(grep -m1 -E '^REMOTE=' "$target" || true)
        fi

        mkdir -p "$(dirname "$target")"
        new="$target.px-new"
        if ! curl -fsSL --max-time 30 "$RAW_BASE/$path" -o "$new"; then
            warn "Failed to download $path"
            rm -f "$new"
            failed=$((failed + 1))
            continue
        fi
        migrate_remote_line "$rel" "$saved_remote"

        if [ -f "$target" ] && cmp -s "$target" "$new"; then
            rm -f "$new"
            continue
        fi
        if [ -f "$target" ]; then
            mkdir -p "$backup/scripts/$(dirname "$rel")"
            cp -a "$target" "$backup/scripts/$rel"
        fi
        if [ "$mode" = 100755 ] || [ "$(head -c2 "$new")" = '#!' ]; then
            chmod 755 "$new"
        else
            chmod 644 "$new"
        fi
        # rename() is atomic and leaves the running copy's inode alone
        mv -f "$new" "$target"
        rm -f "$target.upstream"
        echo -e "${green}Updated ~/.scripts/$rel${nc}"
        updated=$((updated + 1))
    done < <(jq -r --arg p "$prefix" \
        '.tree[] | select(.type == "blob" and (.path | startswith($p))) | [.path, .sha, .mode] | @tsv' "$tree")

    if [ "$updated" -gt 0 ]; then
        ok "Updated $updated script(s). Previous versions: $backup/scripts"
    else
        ok "~/.scripts is already up to date."
    fi
    [ "$failed" -eq 0 ]
}

update_bashrc() {
    local backup="$1" new
    if [ -L "$HOME/.bashrc" ]; then
        say "~/.bashrc is a symlink; not overwriting it."
        return "$SKIPPED"
    fi
    new="$HOME/.bashrc.px-new"
    if ! curl -fsSL --max-time 30 "$RAW_BASE/resources/bash/.bashrc" -o "$new"; then
        warn "Failed to download .bashrc from GitHub."
        rm -f "$new"
        return 1
    fi
    if [ -f "$HOME/.bashrc" ] && cmp -s "$HOME/.bashrc" "$new"; then
        rm -f "$new"
        return 0
    fi
    if [ -f "$HOME/.bashrc" ]; then
        mkdir -p "$backup"
        cp -a "$HOME/.bashrc" "$backup/.bashrc"
    fi
    chmod 644 "$new"
    mv -f "$new" "$HOME/.bashrc"
    ok ".bashrc has been updated. Previous version: $backup/.bashrc"
}

self_update() {
    if [ "${PX_NO_SELF_UPDATE:-0}" = 1 ]; then
        say "PX_NO_SELF_UPDATE=1: leaving ~/.scripts and ~/.bashrc alone."
        return "$SKIP"
    fi
    if ! ensure_jq; then
        record_step "Scripts self-update" failed
        return 1
    fi
    local backup
    backup="$PX_STATE_DIR/backups/scripts-$(date +%Y%m%d-%H%M%S)"
    run_step "Scripts self-update" sync_scripts "$backup"
    run_step ".bashrc update" update_bashrc "$backup"
    prune_backups 'scripts-*' 5
}

# ---------------------------------------------------------------------------
# Snapshots and reboot detection (all distros)
# ---------------------------------------------------------------------------

pre_update_snapshot() {
    [ "${PX_NO_SNAPSHOT:-0}" = 1 ] && return "$SKIP"
    if is_arch_like && pacman -Qq snap-pac >/dev/null 2>&1; then
        say "snap-pac will take pre/post snapshots automatically."
        return 0
    fi
    if command_exists timeshift; then
        say "Creating a timeshift snapshot before updating..."
        sudo timeshift --create --comments "pre-update $(date +%F)" --tags O --scripted
        return
    fi
    if command_exists snapper && sudo snapper -c root list >/dev/null 2>&1; then
        say "Creating a snapper snapshot before updating..."
        sudo snapper -c root create -d "pre-update $(date +%F)" -c number
        return
    fi
    return "$SKIP"
}

check_reboot_needed() {
    local kver pkg
    kver=$(uname -r)
    if [ ! -d "/usr/lib/modules/$kver" ] && [ ! -d "/lib/modules/$kver" ]; then
        REBOOT_REASONS+=("running kernel $kver was replaced")
    fi
    if [ -f /var/run/reboot-required ]; then
        REBOOT_REASONS+=("$(head -n1 /var/run/reboot-required.pkgs 2>/dev/null || echo "packages requested a reboot")")
    fi
    if [ "$DISTRO" = fedora ] && command_exists dnf; then
        dnf needs-restarting -r >/dev/null 2>&1
        [ $? -eq 1 ] && REBOOT_REASONS+=("dnf needs-restarting reports core updates")
    fi
    for pkg in "${UPGRADED_PKGS[@]}"; do
        case "$pkg" in
            linux|linux-lts|linux-zen|linux-hardened|linux-rt|linux-surface|linux-cachyos*|systemd|glibc|mesa|nvidia*|amd-ucode|intel-ucode)
                REBOOT_REASONS+=("$pkg was upgraded") ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Arch / Artix
# ---------------------------------------------------------------------------

arch_check_db_lock() {
    local lck=/var/lib/pacman/db.lck pm
    [ -e "$lck" ] || return 0
    for pm in pacman paru yay pamac pamac-daemon packagekitd; do
        if pgrep -x "$pm" >/dev/null 2>&1; then
            err "Another package manager ($pm) is running and holds the pacman lock. Let it finish, then try again."
            return 1
        fi
    done
    err "Found a stale pacman lock: $lck"
    say "If you are sure no package manager is running, remove it with: sudo rm $lck"
    return 1
}

# Show Arch news newer than the last run. Returns 2 if the user cancels.
arch_news_check() {
    [ "$DISTRO" = arch ] || return "$SKIP"
    [ "$DISTRO_ID" = manjaro ] && return "$SKIP"

    if command_exists informant; then
        if informant check >/dev/null 2>&1; then
            return 0
        fi
        warn "There is unread Arch Linux news."
        if [ "$INTERACTIVE" -eq 1 ]; then
            on_tty informant read
            ask_yes "Continue with the upgrade?" Y || return 2
        else
            informant list --unread 2>/dev/null
        fi
        return 0
    fi

    local feed marker newest=0 shown=0 epoch date title link
    marker="$PX_STATE_DIR/arch-news-seen"
    feed=$(curl -fsS --max-time 10 https://archlinux.org/feeds/news/ 2>/dev/null) || {
        warn "Could not fetch Arch news; check https://archlinux.org/news/ before big upgrades."
        return 1
    }
    local seen
    seen=$(cat "$marker" 2>/dev/null || echo $(( $(date +%s) - 14 * 86400 )))

    while IFS=$'\t' read -r date title link; do
        epoch=$(date -d "$date" +%s 2>/dev/null) || continue
        [ "$epoch" -gt "$newest" ] && newest=$epoch
        if [ "$epoch" -gt "$seen" ]; then
            [ "$shown" -eq 0 ] && warn "Arch Linux news since your last update:"
            printf '  %s  %s\n     %s\n' "$(date -d "@$epoch" +%F)" "$title" "$link"
            shown=$((shown + 1))
        fi
    done < <(printf '%s' "$feed" | awk 'BEGIN{RS="</item>"} {
            i = index($0, "<item>"); if (!i) next; s = substr($0, i)
            t = ""; d = ""; l = ""
            if (match(s, /<title>[^<]*<\/title>/)) t = substr(s, RSTART + 7, RLENGTH - 15)
            if (match(s, /<pubDate>[^<]*<\/pubDate>/)) d = substr(s, RSTART + 9, RLENGTH - 19)
            if (match(s, /<link>[^<]*<\/link>/)) l = substr(s, RSTART + 6, RLENGTH - 13)
            gsub(/&amp;/, "\\&", t); gsub(/&lt;/, "<", t); gsub(/&gt;/, ">", t)
            if (t != "" && d != "") print d "\t" t "\t" l
        }')

    if [ "$shown" -gt 0 ]; then
        if [ "$INTERACTIVE" -eq 1 ]; then
            ask_yes "Read the news above. Continue with the upgrade?" Y || return 2
        else
            return 0   # keep the marker so the news shows again interactively
        fi
    fi
    if [ "$newest" -gt 0 ]; then
        mkdir -p "$PX_STATE_DIR"
        echo "$newest" > "$marker"
    fi
    return 0
}

# Offer update-mirrors.sh when the mirrorlist is stale
maybe_refresh_mirrors() {
    [ "$DISTRO" = arch ] || return "$SKIP"
    local ml=/etc/pacman.d/mirrorlist mirrors_script="$SCRIPT_DIR/update-mirrors.sh" age
    [ -f "$ml" ] && [ -f "$mirrors_script" ] || return "$SKIP"
    age=$(( ( $(date +%s) - $(stat -c %Y "$ml") ) / 86400 ))
    [ "$age" -ge "${PX_MIRROR_MAX_AGE:-30}" ] || return "$SKIP"
    if ask_yes "Your mirrorlist is ${age} days old. Refresh mirrors before upgrading?" N; then
        on_tty env PX_NO_PAUSE=1 bash "$mirrors_script" --yes
        return
    fi
    say "Tip: refresh mirrors from the settings menu (Update Mirrors)."
    return "$SKIP"
}

arch_keyrings() {
    if [ "$DISTRO" = artix ]; then
        echo artix-keyring
        pacman -Qq archlinux-keyring >/dev/null 2>&1 && echo archlinux-keyring
    else
        echo archlinux-keyring
    fi
}

arch_log_has_keyring_error() {
    grep -Eqi "unknown trust|signature from .* is invalid|invalid or corrupted package \(PGP signature\)|required key missing from keyring|could not be looked up remotely" "$1"
}

arch_log_needs_manual_conflict_resolution() {
    grep -Eq "Inner conflicts found:|Conflicting packages will have to be confirmed manually|can not install conflicting packages with --noconfirm|unresolvable package conflicts detected" "$1"
}

# Lines look like: "npm: /usr/lib/node_modules/npm/... exists in filesystem" (gawk, Arch-only)
arch_extract_conflict_paths() {
    awk 'match($0, /^[^:]+: (\/[^ ]+) exists in filesystem$/, m) {print m[1]}' "$1" | sort -u
}

# Typical cause: files created by `npm -g` or other manual installs living under /usr.
# Move *unowned* conflicting paths aside into a timestamped backup and retry.
arch_fix_pacman_conflicting_files() {
    local log_file="$1" p owner
    local -a paths=()
    while IFS= read -r p; do
        [[ -n "$p" ]] && paths+=("$p")
    done < <(arch_extract_conflict_paths "$log_file")
    (( ${#paths[@]} > 0 )) || return 1

    warn "Detected pacman file conflicts:"
    printf ' - %s\n' "${paths[@]}"

    if ! ask_yes "Move unowned conflicting files aside and retry the upgrade?" Y || [ "$INTERACTIVE" -ne 1 ]; then
        echo "Tip: inspect ownership with: pacman -Qo <path>"
        return 2
    fi

    local backup_root
    backup_root="/var/lib/piercingxx/pacman-conflicts-$(date +%Y%m%d-%H%M%S)"
    sudo mkdir -p "$backup_root"
    local moved_any=0
    for p in "${paths[@]}"; do
        sudo test -e "$p" || continue
        owner=$(pacman -Qo "$p" 2>&1 || true)
        if grep -qi "No package owns" <<< "$owner"; then
            sudo mkdir -p "$backup_root$(dirname "$p")"
            sudo mv -f "$p" "$backup_root$(dirname "$p")/" && moved_any=1
        else
            warn "Skipping owned path: $p"
            echo "  $owner"
        fi
    done
    if (( moved_any == 1 )); then
        ok "Moved unowned conflicting files to: $backup_root"
        return 0
    fi
    warn "No unowned conflicting paths were moved."
    return 2
}

arch_pacman_upgrade() {
    local log_file="$1"
    sudo pacman -Syu --noconfirm 2>&1 | tee "$log_file"
    return "${PIPESTATUS[0]}"
}

arch_downgrade_hint() {
    say "Older package versions are kept in /var/cache/pacman/pkg."
    say "  Roll back one package: sudo pacman -U /var/cache/pacman/pkg/<name>-<oldver>-<arch>.pkg.tar.zst"
    if command_exists downgrade; then
        say "  Or pick a version interactively: sudo downgrade <name>"
    fi
}

# Official-repo upgrade: non-interactive, with keyring/conflict repair
arch_repo_upgrade() {
    local log_file="$PX_TMP_DIR/pacman-upgrade.log"

    arch_pacman_upgrade "$log_file" && return 0

    if arch_log_has_keyring_error "$log_file"; then
        warn "Package signature problem; refreshing the keyring first..."
        # shellcheck disable=SC2046
        if sudo pacman -Sy --needed --noconfirm $(arch_keyrings) && arch_pacman_upgrade "$log_file"; then
            return 0
        fi
    fi

    if arch_log_needs_manual_conflict_resolution "$log_file" && [ "$INTERACTIVE" -eq 1 ]; then
        warn "The upgrade needs you to confirm a package conflict or replacement."
        if ask_yes "Re-run the upgrade interactively now?" Y; then
            on_tty sudo pacman -Syu && return 0
        fi
    fi

    if grep -q "failed to commit transaction (conflicting files)" "$log_file"; then
        warn "Upgrade failed due to conflicting files; attempting repair..."
        if arch_fix_pacman_conflicting_files "$log_file" && arch_pacman_upgrade "$log_file"; then
            return 0
        fi
    fi

    local saved="$PX_STATE_DIR/logs/pacman-failed-$(date +%Y%m%d-%H%M%S).log"
    cp "$log_file" "$saved" 2>/dev/null
    err "System upgrade did not complete. pacman output: $saved"
    arch_downgrade_hint
    return 1
}

# paru links against libalpm; a pacman soname bump breaks it until rebuilt
rebuild_paru_if_broken() {
    command_exists paru || return "$SKIP"
    local paru_err
    paru_err=$(paru --version 2>&1 >/dev/null) && return "$SKIP"

    local cooldown_file="$PX_STATE_DIR/paru-rebuild-skip" now last
    if [ -f "$cooldown_file" ]; then
        now=$(date +%s)
        last=$(stat -c %Y "$cooldown_file" 2>/dev/null || echo 0)
        if [ $((now - last)) -lt 86400 ]; then
            warn "paru is broken; skipping rebuild (a rebuild failed in the last 24h)."
            return 1
        fi
    fi
    if ! command_exists git || ! command_exists makepkg; then
        warn "paru is broken and git/makepkg are missing; cannot rebuild it."
        return 1
    fi

    if grep -q "libalpm" <<< "$paru_err"; then
        warn "paru is broken (libalpm ABI mismatch); rebuilding from the AUR..."
    else
        warn "paru is broken ($paru_err); rebuilding from the AUR..."
    fi
    sudo pacman -R --noconfirm paru-bin >/dev/null 2>&1 || true
    local tmpdir
    tmpdir=$(mktemp -d "$PX_TMP_DIR/paru.XXXXXX")
    mkdir -p "$PX_STATE_DIR"
    if git clone --quiet https://aur.archlinux.org/paru.git "$tmpdir/paru" \
        && (cd "$tmpdir/paru" && makepkg -si --noconfirm); then
        rm -f "$cooldown_file"
        rm -rf "$tmpdir"
        return 0
    fi
    touch "$cooldown_file"
    rm -rf "$tmpdir"
    warn "paru rebuild failed; AUR updates will be skipped."
    return 1
}

# AUR upgrade: interactive by default so PKGBUILD changes can be reviewed
arch_aur_upgrade() {
    local helper pending
    helper=$(aur_helper)
    [ -n "$helper" ] || return "$SKIP"
    if ! "$helper" --version >/dev/null 2>&1; then
        warn "$helper is not working; skipping AUR updates."
        return 1
    fi
    pending=$("$helper" -Qua 2>/dev/null | grep -vc '\[ignored\]')
    if [ "${pending:-0}" -eq 0 ]; then
        ok "AUR packages are up to date."
        return 0
    fi
    if [ "${PX_AUR_NOCONFIRM:-0}" = 1 ]; then
        say "Upgrading $pending AUR package(s) with $helper (no review: PX_AUR_NOCONFIRM=1)..."
        "$helper" -Sua --noconfirm
        return
    fi
    if [ "$INTERACTIVE" -eq 1 ]; then
        say "Upgrading $pending AUR package(s) with $helper. Review PKGBUILD changes when asked."
        on_tty "$helper" -Sua
        return
    fi
    warn "Skipping $pending AUR update(s) in a non-interactive run. Run '$helper -Sua' or set PX_AUR_NOCONFIRM=1."
    return "$SKIPPED"
}

arch_collect_upgraded() {
    local start_line="$1" log=/var/log/pacman.log
    [ -r "$log" ] || return 0
    mapfile -t UPGRADED_PKGS < <(tail -n +"$((start_line + 1))" "$log" \
        | awk '$2 == "[ALPM]" && ($3 == "upgraded" || $3 == "installed") {print $4}' | sort -u)
}

arch_bootloader_checks() {
    local pkg img
    if printf '%s\n' "${UPGRADED_PKGS[@]}" | grep -qx systemd \
        && command_exists bootctl && sudo bootctl is-installed >/dev/null 2>&1; then
        say "systemd was upgraded; updating systemd-boot..."
        sudo bootctl update --graceful || return 1
    fi
    # A full /boot or an unmounted ESP silently leaves a stale initramfs behind
    for pkg in "${UPGRADED_PKGS[@]}"; do
        case "$pkg" in
            linux|linux-*) ;;
            *) continue ;;
        esac
        [[ "$pkg" == *-headers || "$pkg" == *-firmware* || "$pkg" == *-api-headers ]] && continue
        img="/boot/initramfs-$pkg.img"
        [ -f "$img" ] || continue
        if [ "$(stat -c %Y "$img")" -lt "$START_EPOCH" ]; then
            err "$pkg was upgraded but $img was not regenerated. Check that /boot is mounted and has space, then run: sudo mkinitcpio -P"
            return 1
        fi
    done
    return 0
}

arch_report_pacnew() {
    local list
    if command_exists pacdiff; then
        list=$(pacdiff -o 2>/dev/null)
    else
        list=$(find /etc \( -name '*.pacnew' -o -name '*.pacsave' \) 2>/dev/null)
    fi
    [ -n "$list" ] || return 0
    warn "Config files waiting to be merged:"
    # shellcheck disable=SC2086
    printf '  %s\n' $list
    if command_exists pacdiff && ask_yes "Review them now with pacdiff?" N; then
        on_tty sudo env DIFFPROG="${DIFFPROG:-nvim -d}" pacdiff
    else
        say "Merge later with: sudo DIFFPROG='nvim -d' pacdiff (pacman-contrib)"
    fi
    return 0
}

arch_post_checks() {
    if command_exists paccache; then
        sudo paccache -rk2 -q || true
    fi
    if command_exists arch-audit; then
        local vulns
        vulns=$(arch-audit -u 2>/dev/null)
        if [ -n "$vulns" ]; then
            warn "Installed packages with known vulnerabilities that have a fix available:"
            printf '%s\n' "$vulns" | sed 's/^/  /'
        fi
    fi
    local orphans
    orphans=$(pacman -Qtdq 2>/dev/null | wc -l)
    if [ "$orphans" -gt 0 ]; then
        say "$orphans orphaned package(s) found; remove them with Clean System."
    fi
}

arch_update() {
    arch_check_db_lock || return 1

    arch_news_check
    if [ $? -eq 2 ]; then
        say "Upgrade cancelled so you can read the news."
        return 2
    fi
    run_step "Mirror refresh" maybe_refresh_mirrors
    run_step "Pre-update snapshot" pre_update_snapshot

    local paclog_start
    paclog_start=$(wc -l < /var/log/pacman.log 2>/dev/null || echo 0)

    if ! run_step "System packages (pacman)" arch_repo_upgrade; then
        arch_collect_upgraded "$paclog_start"
        return 1
    fi
    run_step "paru rebuild" rebuild_paru_if_broken
    local aur_rc
    run_step "AUR packages" arch_aur_upgrade
    aur_rc=$?
    if [ "$aur_rc" -ne 0 ] && [ "$aur_rc" -ne "$SKIP" ] && [ "$aur_rc" -ne "$SKIPPED" ]; then
        arch_downgrade_hint
    fi

    arch_collect_upgraded "$paclog_start"
    run_step "Bootloader / initramfs" arch_bootloader_checks
    arch_report_pacnew
    arch_post_checks
    return 0
}

# ---------------------------------------------------------------------------
# Other distros
# ---------------------------------------------------------------------------

debian_fix_node_gyp_conflicts() {
    say "Attempting node-gyp reinstall fix (Debian/Ubuntu)..."
    sudo -E apt-get -y install --reinstall node-gyp npm || true
    sudo -E apt-get -y install --reinstall nodejs npm || true
}

fedora_fix_node_gyp_conflicts() {
    say "Attempting node-gyp reinstall fix (Fedora)..."
    sudo dnf -y reinstall nodejs npm node-gyp || true
    sudo dnf -y reinstall nodejs npm || true
}

debian_upgrade() {
    export DEBIAN_FRONTEND=noninteractive
    export APT_LISTCHANGES_FRONTEND=none
    local -a dpkg_opts=(-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
    sudo -E apt-get update || return 1
    sudo -E apt-get "${dpkg_opts[@]}" -y full-upgrade || {
        sudo dpkg --configure -a || true
        sudo -E apt-get "${dpkg_opts[@]}" -y --fix-broken install || true
        sudo -E apt-get "${dpkg_opts[@]}" -y full-upgrade || return 1
    }
    sudo -E apt-get -y autoremove || true
}

fedora_upgrade() {
    sudo dnf -y upgrade --refresh
}

# Retry once after the node-gyp/npm reinstall that usually unblocks these
debian_upgrade_with_fix() {
    debian_upgrade && return 0
    warn "apt upgrade failed; attempting node-gyp fix..."
    debian_fix_node_gyp_conflicts
    debian_upgrade
}

fedora_upgrade_with_fix() {
    fedora_upgrade && return 0
    warn "dnf upgrade failed; attempting node-gyp fix..."
    fedora_fix_node_gyp_conflicts
    fedora_upgrade
}

suse_upgrade() {
    sudo zypper -n refresh || return 1
    case "$DISTRO_ID" in
        opensuse-tumbleweed|opensuse-slowroll|opensuse-microos)
            sudo zypper -n dup ;;
        *)
            sudo zypper -n update ;;
    esac
}

void_upgrade() {
    local -a yes=()
    [ "$INTERACTIVE" -eq 1 ] || yes=(-y)
    # xbps must be current before the rest of the system can update
    sudo xbps-install -S -u "${yes[@]}" xbps || true
    sudo xbps-install -Su "${yes[@]}" || return 1
    sudo xbps-remove -Oo "${yes[@]}" || true
}

alpine_upgrade() {
    sudo apk update || return 1
    sudo apk upgrade || return 1
}

ubuntu_touch_upgrade() {
    say "Ubuntu Touch detected: the system image is read-only and updates over-the-air."
    if command_exists system-image-cli; then
        say "Checking for an OTA system update (applied on next reboot)..."
        sudo system-image-cli --progress dots
    else
        say "Use System Settings -> Updates for system updates."
        return "$SKIPPED"
    fi
}

# Keep Synology Drive client updated on Debian/Ubuntu by pulling the current installer
update_synology_drive() {
    command_exists dpkg && command_exists apt || return "$SKIP"
    dpkg-query -W synology-drive-client >/dev/null 2>&1 || return "$SKIP"
    # Synology only publishes an x86_64 build; skip on ARM phones (FuriOS/Mobian/Droidian)
    [ "$(dpkg --print-architecture 2>/dev/null)" = "amd64" ] || return "$SKIP"
    local version="4.0.1-17885"
    local build="${version##*-}"
    local base_url="https://global.download.synology.com/download/Utility/SynologyDriveClient/${version}/Ubuntu/Installer"
    local pkg="synology-drive-client-${build}.x86_64.deb"
    local installed tmp_pkg
    installed=$(dpkg-query -W -f='${Version}' synology-drive-client 2>/dev/null || true)
    [ "$installed" = "$version" ] && return 0
    tmp_pkg=$(mktemp "$PX_TMP_DIR/synology.XXXXXX.deb")
    if curl -fsSL "${base_url}/${pkg}" -o "$tmp_pkg"; then
        sudo dpkg -i "$tmp_pkg" || sudo apt-get --fix-broken install -y
    else
        warn "Synology Drive download failed; keeping existing version."
        return 1
    fi
}

hypr_cmake_build() {
    local name="$1" url="$2" tag="$3" tmp rc=0
    tmp=$(mktemp -d "$PX_TMP_DIR/hypr.XXXXXX")
    say "Building ${name} ${tag}..."
    if git clone --quiet --depth 1 --recursive --branch "$tag" "$url" "$tmp/$name"; then
        (cd "$tmp/$name" \
            && cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_INSTALL_PREFIX=/usr -S . -B build \
            && cmake --build build --config Release -j"$(nproc 2>/dev/null || echo 2)" \
            && sudo cmake --install build) || { warn "${name} build failed; leaving existing install."; rc=1; }
    else
        warn "Could not clone ${name} ${tag}."
        rc=1
    fi
    rm -rf "$tmp"
    return "$rc"
}

# Rebuild a source-built Hyprland stack on Debian/Ubuntu when the pin moves.
# Pins match linux-mod modules/wm.sh (_wm_hyprland_debian_source_build); keep them in sync.
update_hyprland_builds() {
    [ "$DISTRO" = debian ] || return "$SKIP"
    local bin
    bin=$(command -v Hyprland || command -v hyprland) || return "$SKIP"
    bin=$(readlink -f "$bin")
    # Packaged Hyprland is handled by apt
    dpkg -S "$bin" >/dev/null 2>&1 && return "$SKIP"

    local hyprland_tag="v0.55.3"
    if "$bin" --version 2>/dev/null | grep -q "${hyprland_tag#v}"; then
        return "$SKIP"
    fi
    if ! command_exists git || ! command_exists cmake || ! command_exists meson; then
        warn "git/cmake/meson missing; skipping Hyprland rebuild."
        return 1
    fi

    if command_exists clang++-19; then
        export CC=clang-19 CXX=clang++-19
    elif command_exists clang++-18; then
        export CC=clang-18 CXX=clang++-18
    elif command_exists g++-14; then
        export CC=gcc-14 CXX=g++-14
    fi

    local failed=0 tmp
    hypr_cmake_build hyprwayland-scanner https://github.com/hyprwm/hyprwayland-scanner.git v0.4.6 || failed=1
    hypr_cmake_build hyprutils           https://github.com/hyprwm/hyprutils.git           v0.13.1 || failed=1
    hypr_cmake_build hyprlang            https://github.com/hyprwm/hyprlang.git            v0.6.7 || failed=1
    hypr_cmake_build hyprcursor          https://github.com/hyprwm/hyprcursor.git          v0.1.11 || failed=1
    hypr_cmake_build hyprgraphics        https://github.com/hyprwm/hyprgraphics.git        v0.5.1 || failed=1
    hypr_cmake_build aquamarine          https://github.com/hyprwm/aquamarine.git          v0.9.3 || failed=1

    tmp=$(mktemp -d "$PX_TMP_DIR/hypr.XXXXXX")
    if git clone --quiet --depth 1 --branch v0.7.0 https://github.com/hyprwm/hyprland-protocols.git "$tmp/hyprland-protocols"; then
        (cd "$tmp/hyprland-protocols" && meson setup build --prefix=/usr && sudo meson install -C build) \
            || { warn "hyprland-protocols install failed."; failed=1; }
    fi
    rm -rf "$tmp"

    tmp=$(mktemp -d "$PX_TMP_DIR/hypr.XXXXXX")
    say "Building Hyprland ${hyprland_tag} (make all)..."
    if git clone --quiet --depth 1 --recursive --branch "$hyprland_tag" https://github.com/hyprwm/Hyprland.git "$tmp/Hyprland"; then
        (cd "$tmp/Hyprland" && make all && sudo make install) || { warn "Hyprland ${hyprland_tag} build failed."; failed=1; }
    else
        warn "Could not clone Hyprland ${hyprland_tag}."
        failed=1
    fi
    rm -rf "$tmp"

    hypr_cmake_build hyprlock  https://github.com/hyprwm/hyprlock.git  v0.5.1 || failed=1
    hypr_cmake_build hypridle  https://github.com/hyprwm/hypridle.git  v0.3.1 || failed=1
    hypr_cmake_build hyprpaper https://github.com/hyprwm/hyprpaper.git v0.7.6 || failed=1
    hypr_cmake_build xdg-desktop-portal-hyprland https://github.com/hyprwm/xdg-desktop-portal-hyprland.git v1.3.9 || failed=1
    sudo ldconfig
    return "$failed"
}

# ---------------------------------------------------------------------------
# Universal steps (every distro, each gated on the tool existing)
# ---------------------------------------------------------------------------

update_firmware() {
    command_exists fwupdmgr || return "$SKIP"
    rootfs_ro && return "$SKIP"
    say "Checking firmware (fwupd)..."
    # fwupd authorizes through polkit; no sudo, so its cache stays per-user
    fwupdmgr refresh </dev/null >/dev/null 2>&1 || true
    fwupdmgr get-updates --no-unreported-check </dev/null >/dev/null 2>&1
    case $? in
        0) fwupdmgr update -y --no-reboot-check || sudo fwupdmgr update -y --no-reboot-check ;;
        2) ok "No firmware updates." ;;
        *) return "$SKIP" ;;   # no supported devices / daemon unavailable
    esac
}

rootfs_ro() {
    awk '$2 == "/" {opts=$4} END {exit !(opts ~ /^ro$|^ro,|,ro,|,ro$)}' /proc/mounts 2>/dev/null
}

update_npm_globals() {
    command_exists npm || return "$SKIP"
    local prefix
    prefix=$(npm config get prefix 2>/dev/null || true)
    case "$prefix" in
        /usr|""|undefined)
            # Package-owned prefix: `npm -g` here collides with pacman/apt/dnf files
            say "Skipping global npm update: npm prefix is $prefix (package-managed)."
            say "Tip: npm config set prefix ~/.local for user-level global installs."
            return "$SKIP" ;;
        /usr/local)
            say "Updating global npm packages (/usr/local)..."
            sudo npm update -g --silent --no-progress ;;
        *)
            say "Updating global npm packages ($prefix)..."
            npm update -g --silent --no-progress ;;
    esac
}

update_cargo() {
    command_exists cargo || return "$SKIP"
    [ -n "$(cargo install --list 2>/dev/null)" ] || return "$SKIP"
    say "Updating cargo-installed binaries..."
    if ! cargo install-update --version >/dev/null 2>&1; then
        cargo install cargo-update || return 1
    fi
    cargo install-update -a
}

update_rustup() {
    command_exists rustup || return "$SKIP"
    rustup toolchain list 2>/dev/null | grep -qv 'no installed toolchains' || return "$SKIP"
    say "Updating Rust toolchains (rustup)..."
    rustup update
}

update_pipx() {
    command_exists pipx || return "$SKIP"
    [ -n "$(pipx list --short 2>/dev/null)" ] || return "$SKIP"
    say "Updating pipx apps..."
    pipx upgrade-all
}

update_uv_tools() {
    command_exists uv || return "$SKIP"
    uv tool list 2>/dev/null | grep -q . || return "$SKIP"
    uv tool list 2>/dev/null | grep -q 'No tools installed' && return "$SKIP"
    say "Updating uv tools..."
    uv tool upgrade --all
}

update_gh_extensions() {
    command_exists gh || return "$SKIP"
    [ -n "$(gh extension list 2>/dev/null)" ] || return "$SKIP"
    say "Updating gh extensions..."
    gh extension upgrade --all
}

update_flatpak() {
    command_exists flatpak || return "$SKIP"
    local rc=0
    say "Updating flatpak (user)..."
    flatpak update --user -y --noninteractive || rc=1
    say "Updating flatpak (system)..."
    sudo flatpak update -y --noninteractive || rc=1
    # Unused runtimes are removed by Clean System, not here
    return "$rc"
}

update_docker_images() {
    command_exists docker || return "$SKIP"
    docker info >/dev/null 2>&1 || return "$SKIP"
    local -a images
    mapfile -t images < <(docker images --format '{{.Repository}}:{{.Tag}}' | grep -v '<none>' | sort -u)
    [ ${#images[@]} -gt 0 ] || return "$SKIP"
    say "Pulling ${#images[@]} Docker image(s)..."
    local img
    for img in "${images[@]}"; do
        echo "  • ${img}"
        # Locally built images have no registry copy; that's fine
        docker pull --quiet "$img" >/dev/null 2>&1 || echo "    (not pulled)"
    done
    say "Unused images and stopped containers are cleaned from Clean System."
    return 0
}

update_yazi() {
    command_exists ya || return "$SKIP"
    local cfg="$HOME/.config/yazi/package.toml" rc=0
    say "Updating yazi plugins..."
    if [ -f "$cfg" ]; then
        sed -i -e 's/system-clipboard\.yazi/system-clipboard-yazi/g' "$cfg" || true
    fi
    ya pkg upgrade || rc=1
    if [ -f "$cfg" ]; then
        local -a desired installed
        local plugin
        mapfile -t desired < <(grep '^use = ' "$cfg" | sed -E 's/use = "(.*)"/\1/' | sort)
        mapfile -t installed < <(ya pkg list 2>/dev/null | awk '{print $1}' | sort)
        for plugin in "${desired[@]}"; do
            if ! printf '%s\n' "${installed[@]}" | grep -qx "$plugin"; then
                say "Adding missing yazi plugin: $plugin"
                ya pkg add "$plugin" || rc=1
            fi
        done
    fi
    return "$rc"
}

update_nvim_plugins() {
    command_exists nvim || return "$SKIP"
    [ -d "${XDG_CONFIG_HOME:-$HOME/.config}/nvim" ] || return "$SKIP"
    say "Updating Neovim plugins (vim.pack)..."
    # force=true applies updates directly instead of opening the review buffer
    nvim --headless \
        "+lua if vim.pack and vim.pack.update then local ok, e = pcall(vim.pack.update, nil, { force = true }); if not ok then io.stderr:write(tostring(e) .. '\n'); vim.cmd('cquit 1') end end" \
        "+qa" 2>&1
}

update_brew() {
    command_exists brew || return "$SKIP"
    say "Updating Homebrew..."
    brew update && brew upgrade
}

update_clamav() {
    command_exists freshclam || return "$SKIP"
    local vs="$SCRIPT_DIR/virus-scan.sh"
    if [ -f "$vs" ] && grep -q -- '--update-db' "$vs"; then
        bash "$vs" --update-db
        return
    fi
    if svc_is_active clamav-freshclam || svc_is_active freshclam; then
        say "The freshclam service keeps ClamAV definitions current; skipping."
        return 0
    fi
    say "Updating ClamAV virus definitions..."
    sudo freshclam
}

update_hyprpm() {
    pgrep -x Hyprland >/dev/null 2>&1 || return "$SKIP"
    command_exists hyprpm || return "$SKIP"
    hyprpm list 2>/dev/null | grep -q . || return "$SKIP"
    say "Updating Hyprland plugins (hyprpm)..."
    hyprpm update && hyprpm reload -n
}

update_snap() {
    command_exists snap || return "$SKIP"
    sudo snap refresh
}

# Fast-forward every clean repo in the GitHub folder
git_pull_all_github_repos() {
    command_exists git || return "$SKIP"
    local base_dir="${PX_GITHUB_DIR:-$PX_WORK_ROOT/GitHub}" alt repo name
    if [ ! -d "$base_dir" ]; then
        for alt in "$HOME/GitHub" "$HOME/Projects" "$HOME/Workspace" "$HOME/src"; do
            if [ -d "$alt" ]; then
                base_dir="$alt"
                break
            fi
        done
    fi
    [ -d "$base_dir" ] || return "$SKIP"

    say "Updating git repositories in $base_dir..."
    local -a updated=() dirty=() failed=() noupstream=()
    for repo in "$base_dir"/*; do
        [ -d "$repo/.git" ] || continue
        name=$(basename "$repo")
        if ! git -C "$repo" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
            noupstream+=("$name")
            continue
        fi
        if [ -n "$(git -C "$repo" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
            dirty+=("$name")
            continue
        fi
        if GIT_TERMINAL_PROMPT=0 git -C "$repo" pull --ff-only --quiet 2>/dev/null; then
            updated+=("$name")
        else
            failed+=("$name")
        fi
    done
    ok "  ${#updated[@]} repo(s) up to date."
    [ ${#dirty[@]} -gt 0 ] && warn "  Skipped (local changes): ${dirty[*]}"
    [ ${#noupstream[@]} -gt 0 ] && say "  No upstream branch: ${noupstream[*]}"
    [ ${#failed[@]} -gt 0 ] && warn "  Could not fast-forward: ${failed[*]}"
    [ ${#failed[@]} -eq 0 ]
}

universal_steps() {
    run_step "Firmware (fwupd)" update_firmware
    run_step "Flatpak" update_flatpak
    run_step "Snap" update_snap
    run_step "Synology Drive" update_synology_drive
    run_step "Hyprland source build" update_hyprland_builds
    run_step "npm globals" update_npm_globals
    run_step "Cargo binaries" update_cargo
    run_step "Rust toolchains" update_rustup
    run_step "pipx apps" update_pipx
    run_step "uv tools" update_uv_tools
    run_step "gh extensions" update_gh_extensions
    run_step "Homebrew" update_brew
    run_step "Docker images" update_docker_images
    run_step "Yazi plugins" update_yazi
    run_step "Neovim plugins" update_nvim_plugins
    run_step "ClamAV definitions" update_clamav
    run_step "Hyprland plugins" update_hyprpm
    run_step "Git repositories" git_pull_all_github_repos
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_summary() {
    local i mark failures=0
    echo
    echo -e "${blue}Update summary${nc}"
    for i in "${!STEP_NAMES[@]}"; do
        case "${STEP_STATUS[$i]}" in
            ok)      mark="${green}ok${nc}" ;;
            skipped) mark="${yellow}skipped${nc}" ;;
            *)       mark="${red}FAILED${nc}"; failures=$((failures + 1)) ;;
        esac
        printf '  %-28s %b\n' "${STEP_NAMES[$i]}" "$mark"
    done
    if [ ${#REBOOT_REASONS[@]} -gt 0 ]; then
        echo
        warn "Reboot recommended:"
        printf '  - %s\n' "${REBOOT_REASONS[@]}" | sort -u
    fi
    echo
    say "Full log: $LOG_FILE"
    return "$failures"
}

notify_result() {
    local core_rc="$1" failures="$2" summary body urgency=normal
    if [ "$core_rc" -ne 0 ]; then
        summary="System update failed"
        body="The package upgrade did not complete. Log: $LOG_FILE"
        urgency=critical
    elif [ "$failures" -gt 0 ]; then
        summary="System update finished with problems"
        body="$failures step(s) failed. Log: $LOG_FILE"
    else
        summary="System update complete"
        body="Everything is up to date."
    fi
    if [ ${#REBOOT_REASONS[@]} -gt 0 ]; then
        body="$body Reboot recommended."
    fi
    notify_replace system-update "$urgency" 10000 software-update-available "$summary" "$body"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    PX_TMP_DIR=$(mktemp -d)
    trap cleanup EXIT
    trap 'exit 130' INT TERM

    # Persistent log (ANSI colors stripped in the file)
    mkdir -p "$PX_STATE_DIR/logs"
    LOG_FILE="$PX_STATE_DIR/logs/update-$(date +%Y%m%d-%H%M%S).log"
    exec > >(tee >(sed -u 's/\x1b\[[0-9;?]*[A-Za-z]//g' >> "$LOG_FILE")) 2>&1
    find "$PX_STATE_DIR/logs" -name 'update-*.log' -mtime +30 -delete 2>/dev/null

    # One update at a time (update-notify.sh also checks this lock)
    if ! single_instance update-system; then
        err "Another system update is already running."
        exit 1
    fi

    if ! check_internet; then
        err "Internet connectivity is required to continue."
        exit 1
    fi

    # postmarketOS ships doas instead of sudo; shim it so the rest of the script works unchanged
    local have_real_sudo=0
    if command_exists sudo; then
        have_real_sudo=1
    elif command_exists doas; then
        sudo() { doas "$@"; }
    fi
    if [ "$have_real_sudo" -eq 1 ]; then
        sudo -v || { err "sudo authentication failed."; exit 1; }
        # Keep-alive (doas has no -v/-n). Drop the lock fd and log pipe so a
        # lingering sleep can't hold either after we exit.
        ( exec 9>&- >/dev/null 2>&1
          while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 60; done ) &
        SUDO_KEEPALIVE_PID=$!
    fi

    echo -e "${green}Starting system update (${DISTRO_ID:-$DISTRO})...${nc}\n"

    local core_rc=0
    if is_arch_like; then
        arch_update
        core_rc=$?
        if [ "$core_rc" -eq 2 ]; then
            print_summary >/dev/null
            exit 0
        fi
    else
        run_step "Pre-update snapshot" pre_update_snapshot
        if is_ubuntu_touch; then
            run_step "System image (OTA)" ubuntu_touch_upgrade
        else
            case "$DISTRO" in
                debian) run_step "System packages (apt)" debian_upgrade_with_fix || core_rc=1 ;;
                fedora) run_step "System packages (dnf)" fedora_upgrade_with_fix || core_rc=1 ;;
                suse)   run_step "System packages (zypper)" suse_upgrade || core_rc=1 ;;
                void)   run_step "System packages (xbps)" void_upgrade || core_rc=1 ;;
                alpine) run_step "System packages (apk)" alpine_upgrade || core_rc=1 ;;
                *)
                    warn "Unrecognized distro '${DISTRO_ID}'; skipped the system package upgrade."
                    record_step "System packages" skipped ;;
            esac
        fi
    fi

    if [ "$core_rc" -eq 0 ]; then
        universal_steps
        self_update
    else
        warn "Skipping the remaining steps because the package upgrade failed."
    fi

    check_reboot_needed
    local failures
    print_summary
    failures=$?
    notify_result "$core_rc" "$failures"

    if [ "$core_rc" -ne 0 ]; then
        return 1
    fi
    ok "System update finished."
    return 0
}

main "$@"; exit $?
