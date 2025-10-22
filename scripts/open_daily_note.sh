#!/bin/bash
# filepath: /home/dr3k/open_daily_note.sh

JOURNAL_DIR="/media/Archived-Storage/[03] Other/My Life/02 Journal"
DATE="$(date +%Y-%m-%d)"
NOTE_FILE="$JOURNAL_DIR/$DATE.md"
TIME="  $(date +%H:%M:%S)  "

mkdir -p "$JOURNAL_DIR"
if [ ! -f "$NOTE_FILE" ]; then
    echo "# Journal for $DATE" > "$NOTE_FILE"
    echo "" >> "$NOTE_FILE"
fi

# Insert blank line before time, but NOT after
echo -e "\n$TIME" >> "$NOTE_FILE"

# Open in nvim at the end of the file, move up one line, go to end, and start insert mode
nvim +"normal GA" +"startinsert" "$NOTE_FILE"