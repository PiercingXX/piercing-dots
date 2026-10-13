#!/bin/bash
# GitHub.com/PiercingXX
# Open a tmux layout on one of the remote boxes over SSH.
#
# Usage: remote-session.sh [--host NAME|user@host] [--layout monitor|shell|ollama] [--model MODEL]
#   --host     server (default), skippy, or any user@host
#   --layout   monitor: nvtop/htop/lnav/temps   shell: plain tmux session
#              ollama: `ollama run MODEL`
#
# Hosts come from ~/.config/piercingxx/remotes.conf (shell syntax), e.g.
#   SERVER_HOST="piercingxx@server-debian-ai"
#   SKIPPY_HOST="piercingxx@skippy-debian-5090"
# or the env vars PX_SERVER_HOST / PX_SKIPPY_HOST.
# Authentication is whatever ssh is set up for (keys/agent first, ssh's own
# password prompt otherwise) — no passwords pass through this script.

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

CONF="${XDG_CONFIG_HOME:-$HOME/.config}/piercingxx/remotes.conf"
SERVER_HOST="piercingxx@server-debian-ai"
SKIPPY_HOST="piercingxx@skippy-debian-5090"
# shellcheck disable=SC1090
[ -r "$CONF" ] && . "$CONF"
SERVER_HOST="${PX_SERVER_HOST:-$SERVER_HOST}"
SKIPPY_HOST="${PX_SKIPPY_HOST:-$SKIPPY_HOST}"

host="server"
layout="monitor"
model="skippy"

usage() {
    sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --host)          host="${2:-}"; shift ;;
        --host=*)        host="${1#--host=}" ;;
        --layout)        layout="${2:-}"; shift ;;
        --layout=*)      layout="${1#--layout=}" ;;
        --model)         model="${2:-}"; shift ;;
        --model=*)       model="${1#--model=}" ;;
        # Flags used by older keybinds
        -monitor|-log)   layout="monitor" ;;
        -remote)         layout="shell" ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done

case "$host" in
    server) remote="$SERVER_HOST" ;;
    skippy) remote="$SKIPPY_HOST" ;;
    *)      remote="$host" ;;
esac

command_exists ssh || die "ssh is not installed."

SSH_OPTS=(
    -o StrictHostKeyChecking=accept-new
    -o ConnectTimeout=10
    -o ServerAliveInterval=20
    -o ServerAliveCountMax=2
)

case "$layout" in
    monitor)
        remote_cmd='
  tmux kill-session -t monitor 2>/dev/null || true
  tmux new-session -d -s monitor -c ~
  tmux send-keys -t monitor "export PATH=/usr/local/sbin:/usr/local/bin:$PATH" Enter
  tmux send-keys -t monitor "nvtop" Enter
  tmux split-window -t monitor -v -c ~
  tmux send-keys -t monitor "htop" Enter
  tmux split-window -t monitor -v -p 40 -c ~
  tmux send-keys -t monitor "cd ~/log && lnav unified-activity" Enter
  WIN=$(tmux list-windows -t monitor -F "#{window_index}" | head -n1)
  PANE=$(tmux list-panes -t monitor:$WIN -F "#{pane_index}" | head -n1)
  tmux select-pane -t monitor:$WIN.$PANE
  tmux split-window -t monitor:$WIN.$PANE -h -p 35 -c ~ "watch -n 2 ~/log/monitor-temps"
  tmux select-pane -t monitor:$WIN.$PANE
  tmux resize-pane -t monitor:$WIN.$PANE -y 25
  tmux attach -t monitor
'
        ;;
    shell)
        remote_cmd='tmux new-session -A -s remote -c ~'
        ;;
    ollama)
        [[ "$model" =~ ^[A-Za-z0-9._:/-]+$ ]] || die "Invalid model name: $model"
        remote_cmd="
  tmux kill-session -t ollama 2>/dev/null || true
  tmux new-session -d -s ollama -c ~
  tmux send-keys -t ollama 'export PATH=/usr/local/sbin:/usr/local/bin:\$PATH' Enter
  tmux send-keys -t ollama 'ollama run $model' Enter
  tmux attach -t ollama
"
        ;;
    *) die "Unknown layout: $layout (monitor|shell|ollama)" ;;
esac

exec ssh "${SSH_OPTS[@]}" -t "$remote" "$remote_cmd"
