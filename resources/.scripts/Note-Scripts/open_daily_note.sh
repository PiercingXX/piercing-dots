#!/bin/bash
# GitHub.com/PiercingXX

NOTE_DIR="/media/Archived-Storage/[03] Other/My Life/02 Daily Note"
DATE="$(date +%Y-%m-%d)"
NOTE_FILE="$NOTE_DIR/$DATE.md"
TIME="  $(date +%H:%M:%S)  "

# TODO location (from Neovim floatingtodo setup)
TODO_DIR="/media/Archived-Storage/[03] Other/My Life/01 Top of the List"
TODO_INDEX_FILE="$TODO_DIR/todo.md"

OPEN_DIR=0
VIEW_ONLY=0
OPEN_SPLIT=0
OPEN_TODO=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --directory)
            OPEN_DIR=1
            ;;
        --view|-v)
            VIEW_ONLY=1
            ;;
        --split|-t)
            OPEN_SPLIT=1
            ;;
        --todo|-T)
            OPEN_TODO=1
            ;;
        *)
            # ignore unknown args for now
            ;;
    esac
    shift
done

# Ensure directories exist
mkdir -p "$NOTE_DIR"
mkdir -p "$TODO_DIR"

# If requested, open the notes directory and exit early
if [[ $OPEN_DIR -eq 1 ]]; then
    exec yazi "$NOTE_DIR"
    exit 0
fi

# Initialize today's note if missing
if [[ ! -f "$NOTE_FILE" ]]; then
    echo "---" > "$NOTE_FILE"
    echo "# Daily Note $DATE" >> "$NOTE_FILE"
    echo "---" >> "$NOTE_FILE"
    echo "" >> "$NOTE_FILE"
fi

# Optionally initialize a TODO index file (handy if it doesn't exist yet)
if [[ ! -f "$TODO_INDEX_FILE" ]]; then
    echo "# Top of the List" > "$TODO_INDEX_FILE"
    echo "" >> "$TODO_INDEX_FILE"
fi

if [[ $OPEN_TODO -eq 1 ]]; then
    # Open only the TODO file in Neovim
    if [[ $VIEW_ONLY -eq 0 ]]; then
        exec nvim "$TODO_INDEX_FILE"
    else
        exec nvim -R "$TODO_INDEX_FILE"
    fi
elif [[ $OPEN_SPLIT -eq 1 ]]; then
    # Open Daily Note on the left and TODO file on the right, 50/50 split
    NVIM_ARGS=(
        -c "lua vim.wo.winbar = 'Daily Note'"
        -c "vsplit"
        -c "edit ${TODO_INDEX_FILE}"
        -c "lua vim.wo.winbar = 'TODO List'"
        -c "wincmd ="
        -c "wincmd h"
    )
    if [[ $VIEW_ONLY -eq 0 ]]; then
        echo -e "\n$TIME" >> "$NOTE_FILE"
        exec nvim "${NVIM_ARGS[@]}" -c "normal! GA" -c "startinsert" "$NOTE_FILE"
    else
        exec nvim "${NVIM_ARGS[@]}" "$NOTE_FILE"
    fi
else
    # Original single-buffer behavior
    if [[ $VIEW_ONLY -eq 0 ]]; then
        echo -e "\n$TIME" >> "$NOTE_FILE"
        exec nvim +"normal GA" +"startinsert" "$NOTE_FILE"
    else
        exec nvim "$NOTE_FILE"
    fi
fi