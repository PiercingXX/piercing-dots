#!/usr/bin/env bash
set -euo pipefail

# Start a desktop session via greetd (display-manager.service).
# Automatically repairs common greetd misconfigurations before starting.
# Supports: Arch, Fedora, Debian, Void, FreeBSD

GREETD_CONFIG=/etc/greetd/config.toml
GREETD_DROPIN_DIR=/etc/systemd/system/greetd.service.d
DM_SYMLINK=/etc/systemd/system/display-manager.service
GREETD_SERVICE=/usr/lib/systemd/system/greetd.service
INIT_SYSTEM=""
RELOAD_NEEDED=0
FIXES_APPLIED=()
DISTRO=""

log() {
    printf '[session-launch] %s\n' "$*" >&2
}

die() {
    log "ERROR: $*"
    exit 1
}

fix() {
    log "FIX: $*"
    FIXES_APPLIED+=("$*")
}

ok() {
    log "✓ $*"
}

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case "$ID" in
            arch|manjaro) echo "arch" ;;
            fedora|rhel|centos) echo "fedora" ;;
            debian|ubuntu|pop|mint) echo "debian" ;;
            void) echo "void" ;;
            freebsd) echo "freebsd" ;;
            *) echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}

detect_init_system() {
    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        echo "systemd"
    elif command -v sv >/dev/null 2>&1 && [[ -d /etc/sv ]]; then
        echo "runit"
    else
        echo "unknown"
    fi
}

get_runit_service_dir() {
    if [[ -e /var/service ]]; then
        printf '%s\n' /var/service
    elif [[ -d /etc/runit/runsvdir/current ]]; then
        printf '%s\n' /etc/runit/runsvdir/current
    elif [[ -d /etc/runit/runsvdir/default ]]; then
        printf '%s\n' /etc/runit/runsvdir/default
    else
        return 1
    fi
}

service_exists() {
    local service_name="$1"

    case "$INIT_SYSTEM" in
        systemd)
            [[ -f "$GREETD_SERVICE" ]] || systemctl list-unit-files "$service_name.service" >/dev/null 2>&1
            ;;
        runit)
            [[ -d "/etc/sv/$service_name" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

service_is_enabled() {
    local service_name="$1"
    local service_dir

    case "$INIT_SYSTEM" in
        systemd)
            systemctl is-enabled "$service_name.service" >/dev/null 2>&1
            ;;
        runit)
            service_dir="$(get_runit_service_dir)" || return 1
            [[ -e "$service_dir/$service_name" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

service_is_active() {
    local service_name="$1"

    case "$INIT_SYSTEM" in
        systemd)
            systemctl is-active --quiet "$service_name.service"
            ;;
        runit)
            sv status "$service_name" 2>/dev/null | grep -q '^run:'
            ;;
        *)
            return 1
            ;;
    esac
}

enable_service() {
    local service_name="$1"
    local service_dir

    case "$INIT_SYSTEM" in
        systemd)
            sudo systemctl enable "$service_name.service"
            RELOAD_NEEDED=1
            ;;
        runit)
            service_dir="$(get_runit_service_dir)" || die "Unable to determine runit service directory."
            sudo mkdir -p "$service_dir"
            if [[ ! -e "$service_dir/$service_name" ]]; then
                sudo ln -s "/etc/sv/$service_name" "$service_dir/$service_name"
            fi
            sudo sv up "$service_name" >/dev/null 2>&1 || true
            ;;
    esac
}

disable_service() {
    local service_name="$1"
    local service_dir
    local current_tty=""

    case "$INIT_SYSTEM" in
        systemd)
            sudo systemctl disable "$service_name.service" 2>/dev/null || true
            if systemctl is-active "$service_name.service" >/dev/null 2>&1; then
                sudo systemctl stop "$service_name.service" 2>/dev/null || true
            fi
            RELOAD_NEEDED=1
            ;;
        runit)
            service_dir="$(get_runit_service_dir)" || return 0

            # Avoid disrupting or hanging the current console session when this
            # script is launched from tty1 and we are disabling agetty-tty1.
            current_tty="$(tty 2>/dev/null || true)"
            if [[ "$service_name" == "agetty-tty1" && "$current_tty" == "/dev/tty1" ]]; then
                log "Skipping sv down for agetty-tty1 on active tty1; removing enable symlink only."
            else
                if command -v timeout >/dev/null 2>&1; then
                    sudo timeout 3 sv down "$service_name" 2>/dev/null || true
                else
                    sudo sv down "$service_name" 2>/dev/null || true
                fi
            fi

            sudo rm -f "$service_dir/$service_name"
            ;;
    esac
}

reload_service_manager() {
    case "$INIT_SYSTEM" in
        systemd)
            log "Reloading systemd daemon..."
            sudo systemctl daemon-reload
            ;;
        runit)
            :
            ;;
    esac
}

start_service() {
    local service_name="$1"

    case "$INIT_SYSTEM" in
        systemd)
            sudo systemctl start "$service_name.service"
            ;;
        runit)
            sudo sv up "$service_name"
            ;;
    esac
}

install_package() {
    local pkg="$1"
    local distro="${2:-$DISTRO}"
    
    case "$distro" in
        arch)
            sudo pacman -S --noconfirm "$pkg" 2>/dev/null || return 1
            ;;
        fedora)
            sudo dnf install -y "$pkg" 2>/dev/null || \
            sudo yum install -y "$pkg" 2>/dev/null || return 1
            ;;
        debian)
            sudo apt update >/dev/null 2>&1
            sudo apt install -y "$pkg" 2>/dev/null || return 1
            ;;
        void)
            sudo xbps-install "$pkg" 2>/dev/null || return 1
            ;;
        freebsd)
            sudo pkg install -y "$pkg" 2>/dev/null || return 1
            ;;
        *) return 1 ;;
    esac
}

create_or_add_user() {
    local user="$1"
    if ! id "$user" >/dev/null 2>&1; then
        fix "Creating $user system user..."
        case "$DISTRO" in
            freebsd)
                sudo pw useradd "$user" -d /nonexistent -s /usr/sbin/nologin -m 2>/dev/null || true
                ;;
            *)
                sudo useradd -r -s /usr/sbin/nologin -d /nonexistent "$user" 2>/dev/null || true
                ;;
        esac
    else
        ok "$user user exists"
    fi
}

add_user_to_groups() {
    local user="$1"
    shift
    local groups=("$@")
    
    for group in "${groups[@]}"; do
        # Verify group exists
        if ! getent group "$group" >/dev/null 2>&1; then
            log "WARNING: group $group does not exist (will be skipped)"
            continue
        fi
        
        if ! id -nG "$user" 2>/dev/null | grep -q "\b$group\b"; then
            fix "Adding $user to $group group..."
            case "$DISTRO" in
                freebsd)
                    sudo pw groupmod "$group" -m "$user" 2>/dev/null || true
                    ;;
                *)
                    sudo usermod -a -G "$group" "$user" 2>/dev/null || true
                    ;;
            esac
        fi
    done
}

# ── Preflight ────────────────────────────────────────────────────────────────

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    die "Do not run as root."
fi

if [[ -n ${WAYLAND_DISPLAY:-} || -n ${DISPLAY:-} ]]; then
    die "A graphical session is already active. Run from a text TTY."
fi

for cmd in sudo; do
    command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
done

tty_path="$(tty 2>/dev/null || true)"
if [[ "${1:-}" != "--force-any-tty" && "$tty_path" != /dev/tty* ]]; then
    die "No real TTY detected. Run from a text console or pass --force-any-tty."
fi

DISTRO=$(detect_distro)
[[ "$DISTRO" == "unknown" ]] && die "Unable to detect Linux distribution."
ok "Detected: $DISTRO"

INIT_SYSTEM=$(detect_init_system)
case "$INIT_SYSTEM" in
    systemd)
        ok "Init system: systemd"
        ;;
    runit)
        ok "Init system: runit"
        ;;
    *)
        die "No supported service manager detected. Expected systemd or runit."
        ;;
esac

# ── 1. Ensure greetd is installed ────────────────────────────────────────────

if ! command -v greetd >/dev/null 2>&1 && ! service_exists greetd; then
    fix "greetd not found — attempting to install..."
    if ! install_package greetd "$DISTRO"; then
        die "Failed to install greetd. Install it manually for your distro."
    fi
fi

# ── 2. Ensure tuigreet is installed ──────────────────────────────────────────

if ! command -v tuigreet >/dev/null 2>&1; then
    fix "tuigreet not found — attempting to install..."
    tuigreet_pkg="tuigreet"
    case "$DISTRO" in
        arch) tuigreet_pkg="greetd-tuigreet" ;;
    esac
    
    if ! install_package "$tuigreet_pkg" "$DISTRO"; then
        die "Failed to install tuigreet. Install it manually for your distro."
    fi
fi

# ── 3. Ensure greeter user exists ────────────────────────────────────────────

create_or_add_user "greeter"

# ── 4. Add greeter to necessary groups ───────────────────────────────────────

add_user_to_groups "greeter" "tty" "video" "input"

# ── 5. Fix /etc/greetd/config.toml if [terminal] section is missing ──────────

if [[ -f "$GREETD_CONFIG" ]]; then
    if ! grep -q '^\[terminal\]' "$GREETD_CONFIG"; then
        fix "config.toml is missing [terminal] section — prepending it..."
        existing="$(cat "$GREETD_CONFIG")"
        existing="$(printf '%s\n' "$existing" | grep -v '^vt\s*=')"
        sudo tee "$GREETD_CONFIG" > /dev/null <<EOF
[terminal]
vt = 1

$(printf '%s\n' "$existing" | sed '/^[[:space:]]*$/d')
EOF
        fix "config.toml updated."
    else
        ok "config.toml has [terminal] section"
    fi
else
    fix "config.toml not found — creating default config..."
    sudo mkdir -p /etc/greetd
    sudo tee "$GREETD_CONFIG" > /dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-session --sessions /usr/share/wayland-sessions:/usr/share/xsessions --asterisks"
user = "greeter"
EOF
    fix "config.toml created."
fi

# ── 6. Verify session directories exist ──────────────────────────────────────

for session_dir in /usr/share/wayland-sessions /usr/share/xsessions; do
    if [[ ! -d "$session_dir" ]]; then
        log "WARNING: $session_dir does not exist (sessions may not display in tuigreet)"
    else
        ok "$session_dir exists"
    fi
done

# ── 7. Fix service manager integration ───────────────────────────────────────

case "$INIT_SYSTEM" in
    systemd)
        if [[ -d "$GREETD_DROPIN_DIR" ]]; then
            fix "Found greetd drop-in directory — removing (causes TTY ownership conflicts)..."
            sudo rm -rf "$GREETD_DROPIN_DIR"
            RELOAD_NEEDED=1
        fi

        if [[ ! -e "$DM_SYMLINK" ]]; then
            if [[ -f "$GREETD_SERVICE" ]]; then
                fix "Creating display-manager.service symlink..."
                sudo ln -sf "$GREETD_SERVICE" "$DM_SYMLINK"
                RELOAD_NEEDED=1
            else
                log "WARNING: $GREETD_SERVICE not found; skipping display-manager symlink."
            fi
        else
            ok "display-manager.service symlink exists"
        fi

        if service_is_enabled getty@tty1; then
            fix "getty@tty1 is enabled — disabling to prevent conflict with greetd..."
            disable_service getty@tty1
        else
            ok "getty@tty1 is already disabled"
        fi
        ;;
    runit)
        if service_is_enabled agetty-tty1; then
            fix "agetty-tty1 is enabled — disabling to prevent conflict with greetd..."
            disable_service agetty-tty1
        else
            ok "agetty-tty1 is already disabled"
        fi
        ;;
esac

# ── 8. Ensure greetd is enabled for autostart ────────────────────────────────

if ! service_is_enabled greetd; then
    fix "greetd is not enabled — enabling..."
    enable_service greetd
else
    ok "greetd is enabled"
fi

# ── 9. Reload service manager if anything changed ────────────────────────────

if [[ $RELOAD_NEEDED -eq 1 ]]; then
    reload_service_manager
fi

# ── 10. Start greetd/display manager ─────────────────────────────────────────

case "$INIT_SYSTEM" in
    systemd)
        dm_load_state="$(systemctl show -p LoadState --value display-manager.service 2>/dev/null || true)"
        if [[ "$dm_load_state" == "not-found" || -z "$dm_load_state" ]]; then
            die "display-manager.service still not found after setup. Check greetd installation."
        fi

        if systemctl is-active --quiet display-manager.service; then
            log "display-manager.service (greetd) is already running. Switch to the greeter TTY and log in."
            exit 0
        fi

        log "Starting display-manager.service..."
        sudo systemctl start display-manager.service
        ;;
    runit)
        if ! service_exists greetd; then
            die "greetd runit service directory not found at /etc/sv/greetd."
        fi

        if service_is_active greetd; then
            log "greetd is already running. Switch to the greeter TTY and log in."
            exit 0
        fi

        log "Starting greetd..."
        start_service greetd
        ;;
esac

# ── Summary ──────────────────────────────────────────────────────────────────

echo "" >&2
if [[ ${#FIXES_APPLIED[@]} -gt 0 ]]; then
    log "$(printf '=%.0s' {1..76})"
    log "Applied ${#FIXES_APPLIED[@]} fix(es):"
    for i in "${!FIXES_APPLIED[@]}"; do
        log "  $((i+1)). ${FIXES_APPLIED[$i]}"
    done
    log "$(printf '=%.0s' {1..76})"
else
    ok "All checks passed — no fixes needed"
fi

log "greetd started. Select your session at the tuigreet prompt and log in."
