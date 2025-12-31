#!/usr/bin/env bash

REMOTE="dr3k@server-debian-ai"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o ServerAliveInterval=20 -o ServerAliveCountMax=2"

# Collect password
read -s -p "SSH password for $REMOTE: " SSHPASS
echo
export SSHPASS

# SSH directly and run tmux commands
sshpass -e ssh $SSH_OPTS -t $REMOTE '
  tmux kill-session -t monitor 2>/dev/null || true
  tmux new-session -d -s monitor -c ~
  tmux send-keys -t monitor "nvtop" Enter
  tmux split-window -t monitor -v -c ~
  tmux send-keys -t monitor "htop" Enter
  tmux split-window -t monitor -v -p 40 -c ~
  tmux send-keys -t monitor "cd ~/log && lnav 'unified-activity'" Enter
  tmux select-pane -t monitor:0.0
  tmux resize-pane -t monitor:0.0 -y 25
  tmux attach -t monitor
'