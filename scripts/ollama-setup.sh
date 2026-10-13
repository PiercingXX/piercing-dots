#!/usr/bin/env bash
# GitHub.com/PiercingXX
#
# Ollama install + model-directory migration.
# Installs Ollama (distro package on Arch, upstream installer elsewhere),
# then moves the models directory to a custom location and points the
# systemd service at it.
#
# Usage: sudo ./ollama-setup.sh [--pull]
#   OLLAMA_TARGET=/path   models destination (default: $PIERCINGXX_WORK_ROOT/.ollama-models)
#   OLLAMA_VARIANT=cuda|rocm|cpu   Arch package flavour (default: auto-detect GPU)
#   --pull                pull every uncommented model in ollama-models.txt

set -euo pipefail

script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck disable=SC1091
. "$script_dir/../resources/.scripts/lib/common.sh"

SERVICE="ollama"
TARGET="${OLLAMA_TARGET:-$PX_WORK_ROOT/.ollama-models}"
MODELS_FILE="$script_dir/ollama-models.txt"
PULL=0
[ "${1:-}" = "--pull" ] && PULL=1

echo "=== Ollama Install & Migration Script ==="
echo "Target models directory: $TARGET"
echo ""

if [[ $EUID -ne 0 ]]; then
    die "This script must be run with sudo."
fi

detect_distro
[ "$INIT" = systemd ] || die "Model migration configures a systemd drop-in; $INIT is not supported."

# The target must live on a mounted volume, not silently on the root fs
target_parent="$(dirname "$TARGET")"
if [ ! -d "$target_parent" ]; then
    die "Parent of target does not exist: $target_parent (is the drive mounted? set OLLAMA_TARGET to override)"
fi

dir_empty() { [ -z "$(find "$1" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; }

command_exists rsync || pkg_install rsync

# --- Install --------------------------------------------------------------
arch_variant() {
    case "${OLLAMA_VARIANT:-}" in
        cuda) echo ollama-cuda; return ;;
        rocm) echo ollama-rocm; return ;;
        cpu)  echo ollama; return ;;
    esac
    local gpus
    gpus=$(lspci 2>/dev/null | grep -iE 'vga|3d' || true)
    if grep -qi nvidia <<<"$gpus"; then
        echo ollama-cuda
    elif grep -qiE 'amd|ati' <<<"$gpus"; then
        echo ollama-rocm
    else
        echo ollama
    fi
}

if ! command_exists ollama; then
    echo "📦 Ollama not found. Installing..."
    if is_arch_like; then
        pkg_install "$(arch_variant)"
        systemctl enable --now "$SERVICE"
    else
        tmp_installer=$(mktemp)
        curl -fsSL https://ollama.com/install.sh -o "$tmp_installer"
        sh "$tmp_installer"
        rm -f "$tmp_installer"
    fi
    sleep 2
    echo "✅ Ollama installed"
else
    echo "✅ Ollama is already installed"
fi

# --- Find where the service keeps models today ----------------------------
service_env() {
    systemctl show "$SERVICE" -p Environment --value 2>/dev/null | tr ' ' '\n' | sed -n "s/^$1=//p" | tail -1
}

SOURCE="$(service_env OLLAMA_MODELS)"
if [ -z "$SOURCE" ] || [ "$SOURCE" = "$TARGET" ]; then
    for cand in /var/lib/ollama/.ollama/models /var/lib/ollama /usr/share/ollama/.ollama/models; do
        if [ -d "$cand" ] && [ "$cand" != "$TARGET" ]; then
            SOURCE="$cand"
            break
        fi
    done
fi

svc_user="$(systemctl show "$SERVICE" -p User --value 2>/dev/null || true)"
dynamic_user="$(systemctl show "$SERVICE" -p DynamicUser --value 2>/dev/null || echo no)"

# --- Migrate --------------------------------------------------------------
if [ -d "$TARGET" ] && ! dir_empty "$TARGET"; then
    echo ""
    echo "✅ Target already has models: $TARGET — skipping migration."
elif [ -z "$SOURCE" ] || [ ! -d "$SOURCE" ]; then
    echo "ℹ️  No existing models directory found; target will start empty."
    mkdir -p "$TARGET"
else
    echo ""
    echo "=== Beginning Model Migration ==="
    echo "Source: $SOURCE"
    echo "Target: $TARGET"

    if systemctl is-active --quiet "$SERVICE"; then
        echo "⏹️  Stopping ollama service..."
        systemctl stop "$SERVICE"
        sleep 2
    fi

    mkdir -p "$TARGET"
    if ! dir_empty "$SOURCE"; then
        echo "📋 Copying models (this may take a while)..."
        # Only blobs/ and manifests/ are model data; Arch keeps them directly in /var/lib/ollama
        if [ -d "$SOURCE/blobs" ] || [ -d "$SOURCE/manifests" ]; then
            for sub in blobs manifests; do
                [ -d "$SOURCE/$sub" ] || continue
                rsync -a --info=progress2 "$SOURCE/$sub/" "$TARGET/$sub/"
            done
            echo "✅ Models copied"
            echo "🗑️  Removing original model files..."
            rm -rf "${SOURCE:?}/blobs" "${SOURCE:?}/manifests"
        else
            rsync -a --info=progress2 "$SOURCE/" "$TARGET/"
            echo "✅ Models copied"
            if [ "$SOURCE" != /var/lib/ollama ]; then
                rm -rf "${SOURCE:?}"
            fi
        fi
        echo "✅ Original model files removed"
    else
        echo "ℹ️  No existing models to copy"
    fi
fi

# --- Permissions + service drop-in ----------------------------------------
dropin_dir="/etc/systemd/system/${SERVICE}.service.d"
mkdir -p "$dropin_dir"
{
    echo "[Service]"
    echo "Environment=\"OLLAMA_MODELS=$TARGET\""
    # Hardened units (ProtectSystem/DynamicUser) need explicit write access
    echo "ReadWritePaths=$TARGET"
} > "$dropin_dir/override.conf"
echo "📝 Wrote $dropin_dir/override.conf"

if [ "$dynamic_user" = yes ]; then
    echo "ℹ️  Service uses DynamicUser; leaving ownership to systemd (StateDirectory)."
    chmod -R u+rwX,g+rX,o+rX "$TARGET"
else
    owner="${svc_user:-ollama}"
    if id "$owner" >/dev/null 2>&1; then
        echo "🔐 Setting permissions for $owner..."
        chown -R "$owner":"$(id -gn "$owner")" "$TARGET"
        chmod -R u+rwX,g+rX,o-rwx "$TARGET"
    else
        warn "Service user '$owner' not found; check ownership of $TARGET manually."
    fi
fi

systemctl daemon-reload
systemctl restart "$SERVICE"
sleep 3

echo ""
echo "=== Verification ==="
systemctl show "$SERVICE" -p Environment | grep OLLAMA_MODELS || warn "OLLAMA_MODELS not in the service environment"
journalctl -u "$SERVICE" -n 20 --no-pager | grep -i error || echo "✅ No errors in logs"

# --- Optional model pulls -------------------------------------------------
if [ "$PULL" -eq 1 ] && [ -f "$MODELS_FILE" ]; then
    echo ""
    echo "=== Pulling models from $(basename "$MODELS_FILE") ==="
    grep -vE '^\s*(#|$)' "$MODELS_FILE" | while read -r model; do
        echo "⬇️  $model"
        ollama pull "$model" || warn "Pull failed: $model"
    done
fi

echo ""
echo "✅ Installation & Migration Complete!"
echo "Models live in: $TARGET"
echo "Next: 'ollama list', or edit $(basename "$MODELS_FILE") and rerun with --pull."
