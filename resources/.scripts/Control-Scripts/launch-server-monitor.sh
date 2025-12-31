#!/usr/bin/env bash

REMOTE="dr3k@server-debian-ai"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o ServerAliveInterval=20 -o ServerAliveCountMax=2"

# Collect password
read -s -p "SSH password for $REMOTE: " SSHPASS
echo
export SSHPASS

# Kill existing sessions to ensure fresh layout
tmux kill-session -t server-monitor 2>/dev/null

# Create local tmux session that wraps the remote SSH connection
tmux new-session -d -s server-monitor
tmux send-keys -t server-monitor "export SSHPASS='$SSHPASS'" Enter
tmux send-keys -t server-monitor "sshpass -e ssh $SSH_OPTS -t $REMOTE bash -c '
  tmux kill-session -t monitor 2>/dev/null
  tmux new-session -d -s monitor
  tmux send-keys -t monitor \"nvtop\" Enter
  tmux split-window -t monitor -v
  tmux send-keys -t monitor \"htop\" Enter
  tmux split-window -t monitor -v -p 40
  tmux send-keys -t monitor \"cd ~/log && lnav \\\"hhamanagement.com login\\\"\" Enter
  tmux select-pane -t monitor:0.0
  tmux resize-pane -t monitor:0.0 -y 25
  tmux select-pane -t monitor:0.0
  tmux attach -t monitor
'" Enter

# Attach to local tmux session in kitty
kitty tmux attach -t server-monitor


