#!/usr/bin/env bash

REMOTE="piercingxx@server-debian-ai"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o ServerAliveInterval=20 -o ServerAliveCountMax=2"

# Collect password
read -s -p "SSH password for $REMOTE: " SSHPASS
echo
export SSHPASS

# SSH directly and run tmux commands
sshpass -e ssh $SSH_OPTS -t $REMOTE '
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
