#!/bin/bash
# GitHub.com/PiercingXX
# Run an Ollama model in tmux on the server.
# Usage: launch-ollama-remote.sh [--skippy|--gpt|--gemma] [--host NAME]

model="skippy"
args=()
while [ $# -gt 0 ]; do
    case "$1" in
        -skippy|--skippy) model="skippy-v2" ;;
        -gpt|--gpt)       model="gpt-oss:20b" ;;
        -gemma|--gemma)   model="gemma3:27b-it-qat" ;;
        *)                args+=("$1") ;;
    esac
    shift
done

exec bash "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/remote-session.sh" \
    --host server --layout ollama --model "$model" "${args[@]}"
