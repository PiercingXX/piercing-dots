#!/usr/bin/env bash

REMOTE="piercingxx@server-debian-ai"
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o ServerAliveInterval=20 -o ServerAliveCountMax=2"

# Default model
MODEL="skippy"

# Parse flags
while [[ $# -gt 0 ]]; do
  case $1 in
    -skippy|--skippy)
      MODEL="skippy-v2"
      shift
      ;;
    -gpt|--gpt)
      MODEL="gpt-oss:20b"
      shift
      ;;
    -gemma|--gemma)
      MODEL="gemma3:27b-it-qat"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [-skippy|--skippy] [-gpt|--gpt] [-gemma|--gemma]"
      exit 1
      ;;
  esac
done

# Collect password
read -s -p "SSH password for $REMOTE: " SSHPASS
echo
export SSHPASS

# SSH directly and run tmux commands
sshpass -e ssh $SSH_OPTS -t $REMOTE "
  tmux kill-session -t ollama 2>/dev/null || true
  tmux new-session -d -s ollama -c ~
  tmux send-keys -t ollama 'export PATH=/usr/local/sbin:/usr/local/bin:\$PATH' Enter
  tmux send-keys -t ollama 'ollama run $MODEL' Enter
  tmux attach -t ollama
"
