#!/usr/bin/env bash

REMOTE="piercingxx@server-debian-ai"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o ServerAliveInterval=20 -o ServerAliveCountMax=2"

SESSION="hermes"
HERMES_CMD="hermes"

# Collect password
read -s -p "SSH password for $REMOTE: " SSHPASS
echo
export SSHPASS

# SSH directly and run tmux commands
sshpass -e ssh $SSH_OPTS -t $REMOTE "
  tmux kill-session -t $SESSION 2>/dev/null || true
  tmux new-session -d -s $SESSION -c ~
  tmux send-keys -t $SESSION 'export PATH=/usr/local/sbin:/usr/local/bin:\$PATH' Enter
  tmux send-keys -t $SESSION '$HERMES_CMD' Enter
  tmux attach -t $SESSION
"
