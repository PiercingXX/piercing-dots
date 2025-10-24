#!/bin/bash

NOTE_DIR="/media/Archived-Storage/[03] Other/My Life/02 Daily Note"
DATE="$(date +%Y-%m-%d)"
NOTE_FILE="$NOTE_DIR/$DATE.md"

mkdir -p "$NOTE_DIR"
if [ ! -f "$NOTE_FILE" ]; then
    echo "---" > "$NOTE_FILE"
    echo "# Daily Note $DATE" >> "$NOTE_FILE"
    echo "---" >> "$NOTE_FILE"
    echo "" >> "$NOTE_FILE"
fi

# Open yazi in NOTE_DIR with cursor on today's note
if command -v yazi >/dev/null 2>&1; then
    yazi "$NOTE_DIR" -- -b "$NOTE_FILE"
else
    echo "yazi is not installed or not in PATH."
    exit 1
fi
