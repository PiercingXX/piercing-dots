#!/bin/bash
# GitHub.com/PiercingXX

NOTE_DIR="/media/Archived-Storage/[03] Other/My Life/02 Daily Note"
DATE="$(date +%Y-%m-%d)"
NOTE_FILE="$NOTE_DIR/$DATE.md"
TIME="  $(date +%H:%M:%S)  "

mkdir -p "$NOTE_DIR"
if [ ! -f "$NOTE_FILE" ]; then
    echo "---" > "$NOTE_FILE"
    echo "# Daily Note $DATE" >> "$NOTE_FILE"
    echo "---" >> "$NOTE_FILE"
    echo "" >> "$NOTE_FILE"
fi

# Use --view flag to open in view-only mode
if [[ "$1" != "--view" ]]; then
    echo -e "\n$TIME" >> "$NOTE_FILE"
    nvim +"normal GA" +"startinsert" "$NOTE_FILE"
else
    nvim "$NOTE_FILE"
fi