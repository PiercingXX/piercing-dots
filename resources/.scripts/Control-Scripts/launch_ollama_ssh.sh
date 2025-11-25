#!/usr/bin/env bash

# launch_ollama_ssh.sh
# Opens a local terminal, establishes an SSH session to a remote server,
# forwards Ollama's default port, and starts (or attaches to) Ollama.

# ----------------------------- CONFIGURATION -----------------------------
# Edit these to match your environment. You can also override them via env vars
# before calling the script (e.g. SSH_HOST=me@box ./launch_ollama_ssh.sh).

SSH_HOST="dr3k@ai-debian-server"          # user@hostname or host alias from ~/.ssh/config
SSH_PORT="22"                        # SSH port
FORWARD_PORT="11434"                 # Local/remote Ollama port

REMOTE_OLLAMA_CMD="ollama run skippy"

# If you want persistent multiplexed SSH connections, set to 1.
USE_CONTROLMASTER=1

# Additional SSH options (append space-separated flags).
EXTRA_SSH_OPTS="-o ServerAliveInterval=30 -o ServerAliveCountMax=120"

# Uncomment to skip host key checking (NOT recommended for production).
# EXTRA_SSH_OPTS+=" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# --------------------------- END CONFIGURATION ---------------------------

set -euo pipefail

# Allow environment overrides without editing the file (keep existing defaults).
SSH_HOST="${SSH_HOST:-$SSH_HOST}"
SSH_PORT="${SSH_PORT:-$SSH_PORT}"
FORWARD_PORT="${FORWARD_PORT:-$FORWARD_PORT}"
REMOTE_OLLAMA_CMD="${REMOTE_OLLAMA_CMD:-$REMOTE_OLLAMA_CMD}"
USE_CONTROLMASTER="${USE_CONTROLMASTER:-$USE_CONTROLMASTER}"
EXTRA_SSH_OPTS="${EXTRA_SSH_OPTS:-$EXTRA_SSH_OPTS}"

# ---------------------- LOCAL PORT AVAILABILITY CHECK ----------------------
# If the requested local port is busy, automatically choose the next free port.
find_free_port() {
    local base="$1"
    for p in $(seq "$base" "$((base+20))"); do
        if ! ss -ltn sport = ":$p" 2>/dev/null | grep -q LISTEN; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

LOCAL_PORT="$FORWARD_PORT"
if ss -ltn sport = ":$FORWARD_PORT" 2>/dev/null | grep -q LISTEN; then
    if new_port="$(find_free_port "$FORWARD_PORT")"; then
        echo "[info] Local port $FORWARD_PORT busy; using $new_port instead." >&2
        LOCAL_PORT="$new_port"
    else
        echo "[error] Local port $FORWARD_PORT is busy and no alternative free port found." >&2
        exit 1
    fi
fi

# Detect an available terminal emulator.
detect_terminal() {
    local terms=(kitty wezterm alacritty foot gnome-terminal konsole xfce4-terminal xterm)
    for t in "${terms[@]}"; do
        if command -v "$t" >/dev/null 2>&1; then
            echo "$t"
            return 0
        fi
    done
    return 1
}

TERMINAL="${TERMINAL:-}"  # allow user override
if [ -z "$TERMINAL" ]; then
    if ! TERMINAL="$(detect_terminal)"; then
        echo "Error: No supported terminal emulator found." >&2
        exit 1
    fi
fi

# Build ControlMaster options if enabled.
CM_OPTS=""
if [ "$USE_CONTROLMASTER" = "1" ]; then
    # Create a per-host socket directory.
    SOCKET_DIR="$HOME/.ssh/cm-sockets"
    mkdir -p "$SOCKET_DIR"
    SOCKET_PATH="$SOCKET_DIR/%h-%p-%r"
    CM_OPTS="-o ControlMaster=auto -o ControlPersist=600 -o ControlPath=$SOCKET_PATH"
fi

# Remote startup sequence: ensure Ollama is up. We also keep the session interactive.
REMOTE_CMD=$(cat <<'EOF'
set -e
FORWARD_PORT="__FORWARD_PORT__"
REMOTE_OLLAMA_CMD="__REMOTE_OLLAMA_CMD__"
if ! pgrep -x ollama >/dev/null 2>&1; then
    echo "[remote] Starting Ollama daemon (ollama serve)..."
    ollama serve >/dev/null 2>&1 &
    for i in $(seq 1 10); do
        sleep 0.5
        nc -z localhost "${FORWARD_PORT}" && break || true
    done
fi
echo "[remote] Executing model command: ${REMOTE_OLLAMA_CMD}";
eval "${REMOTE_OLLAMA_CMD}" || echo "[remote] Warning: model run command failed." >&2
echo "[remote] Ollama should be running. Press Ctrl+C to exit."
exec bash --login
EOF
)
REMOTE_CMD=${REMOTE_CMD//__FORWARD_PORT__/$FORWARD_PORT}
REMOTE_CMD=${REMOTE_CMD//__REMOTE_OLLAMA_CMD__/$REMOTE_OLLAMA_CMD}

# Assemble SSH command.
SSH_BASE=(ssh -p "$SSH_PORT" $CM_OPTS $EXTRA_SSH_OPTS -L "${LOCAL_PORT}:localhost:${FORWARD_PORT}" -t "$SSH_HOST")

# Prepare remote command safely for ssh (single-quote wrapping with escapes).
escape_for_single_quotes() { printf %s "$1" | sed "s/'/'\\''/g"; }
SSH_REMOTE_WRAPPED="bash -lc '$(escape_for_single_quotes "$REMOTE_CMD")'"

run_in_terminal() {
    case "$TERMINAL" in
        gnome-terminal)
            exec gnome-terminal -- bash -c "${SSH_BASE[*]} $SSH_REMOTE_WRAPPED; exec bash" ;;
        konsole)
            exec konsole -e bash -c "${SSH_BASE[*]} $SSH_REMOTE_WRAPPED; exec bash" ;;
        kitty)
            exec kitty bash -c "${SSH_BASE[*]} $SSH_REMOTE_WRAPPED; exec bash" ;;
        wezterm)
            exec wezterm start -- bash -c "${SSH_BASE[*]} $SSH_REMOTE_WRAPPED; exec bash" ;;
        alacritty|foot|xfce4-terminal|xterm)
            exec "$TERMINAL" -e bash -c "${SSH_BASE[*]} $SSH_REMOTE_WRAPPED; exec bash" ;;
        *)
            echo "Unsupported terminal: $TERMINAL" >&2
            return 1 ;;
    esac
}

run_in_terminal
