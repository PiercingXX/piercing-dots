#!/usr/bin/env bash
set -euo pipefail


REMOTE="USER@SERVER TO MONITOR"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o ServerAliveInterval=20 -o ServerAliveCountMax=2"

# --- Helpers ---
have_cmd() { command -v "$1" >/dev/null 2>&1; }

require_cmd() {
  local cmd="$1"
  if ! have_cmd "$cmd"; then
    echo "Error: Required command '$cmd' not found. Please install it first." >&2
    exit 1
  fi
}

# --- Dependencies ---
require_cmd kitty
require_cmd sshpass
require_cmd ssh

# --- Parse flag ---
if [ $# -eq 0 ]; then
  echo "Usage: $0 -monitor | -log" >&2
  exit 1
fi

MODE="$1"

# --- Collect password once ---
trap 'unset SSHPASS' EXIT INT TERM
read -s -p "SSH password for $REMOTE: " SSHPASS
echo
export SSHPASS

# --- Launch based on mode ---
case "$MODE" in
  -monitor)
    # Two panes: nvtop on top, htop on bottom using remote control
    SOCK="/tmp/kitty-mon-$$"
    setsid -f kitty -o allow_remote_control=yes --listen-on "unix:${SOCK}" \
      --title "nvtop" sshpass -e ssh $SSH_OPTS -t "$REMOTE" nvtop &
    
    # Wait for socket to be ready
    for _ in $(seq 1 50); do
      if kitty @ --to "unix:${SOCK}" ls >/dev/null 2>&1; then
        break
      fi
      sleep 0.1
    done
    
    # Split horizontally and launch htop in bottom pane
    kitty @ --to "unix:${SOCK}" launch --type=window --location=hsplit \
      --title "htop" --env SSHPASS="$SSHPASS" \
      sshpass -e ssh $SSH_OPTS -t "$REMOTE" htop
    ;;
  -log)
    # Single pane: vi on log file
    setsid -f kitty --title "log" \
      sshpass -e ssh $SSH_OPTS -t "$REMOTE" 'cd ~/log && vi "hhamanagement.com login"'
    ;;
  *)
    echo "Error: Unknown flag '$MODE'. Use -monitor or -log" >&2
    exit 1
    ;;
esac

# Clear password
unset SSHPASS

# Close the invoking Kitty terminal window
if [ -n "${KITTY_WINDOW_ID:-}" ] && [ -n "${KITTY_LISTEN_ON:-}" ]; then
  kitty @ --to "$KITTY_LISTEN_ON" close-window --match id:$KITTY_WINDOW_ID
fi
