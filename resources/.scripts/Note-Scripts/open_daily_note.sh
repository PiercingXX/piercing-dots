#!/bin/bash
# GitHub.com/PiercingXX
# Daily note + TODO list in Neovim.
# Usage: open_daily_note.sh [--split|-t] [--view|-v] [--todo|-T] [--directory] [--no-stamp]
#   Edit modes add a "  HH:MM:SS  " line to today's note; if the last stamp
#   was never written under, it is replaced instead of piling up.
# Notes live under $PIERCINGXX_NOTES_ROOT (default: the Archived-Storage drive).

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

NOTES_ROOT="${PIERCINGXX_NOTES_ROOT:-$PX_ARCHIVE_ROOT/[03] Other/My Life}"
NOTE_DIR="$NOTES_ROOT/02 Daily Note"
DATE="$(date +%Y-%m-%d)"
NOTE_FILE="$NOTE_DIR/$DATE.md"
TIME="  $(date +%H:%M:%S)  "
YAZI_BIN="$(command -v yazi 2>/dev/null || true)"

if [[ -z "$YAZI_BIN" && -x "$HOME/.cargo/bin/yazi" ]]; then
    YAZI_BIN="$HOME/.cargo/bin/yazi"
fi

# TODO location (from Neovim floatingtodo setup)
TODO_DIR="$NOTES_ROOT/01 Top of the List"
TODO_INDEX_FILE="$TODO_DIR/todo.md"

OPEN_DIR=0
VIEW_ONLY=0
OPEN_SPLIT=0
OPEN_TODO=0
STAMP=1
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
        --no-stamp)
            STAMP=0
            ;;
        -h|--help)
            sed -n '3,7p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            printf 'open_daily_note.sh: unknown option %s (try --help)\n' "$1" >&2
            exit 2
            ;;
    esac
    shift
done

fail() {
    notify_replace notes critical 6000 dialog-error "Daily note" "$1"
    printf 'open_daily_note.sh: %s\n' "$1" >&2
    # Usually launched in its own kitty window; keep the message readable
    [[ -t 0 ]] && read -r -t 10 -p "Press Enter to close..." _
    exit 1
}

# The notes drive may not be mounted; don't create a stray tree in /media
[[ -d "$NOTES_ROOT" ]] || fail "Notes folder not found: $NOTES_ROOT (drive not mounted? set PIERCINGXX_NOTES_ROOT)"

mkdir -p "$NOTE_DIR" "$TODO_DIR" || fail "Cannot create note folders under $NOTES_ROOT"

# If requested, open the notes directory and exit early
if [[ $OPEN_DIR -eq 1 ]]; then
    if [[ -z "$YAZI_BIN" ]]; then
        printf 'open_daily_note.sh: yazi not found in PATH or at %s.\n' "$HOME/.cargo/bin/yazi" >&2
        exit 1
    fi

    exec "$YAZI_BIN" "$NOTE_DIR"
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

# Add a time stamp, replacing a previous one that nothing was written under
stamp_note() {
    [[ $STAMP -eq 1 ]] || return 0
    local last
    last="$(grep -v '^[[:space:]]*$' "$NOTE_FILE" | tail -n 1)"
    if [[ "$last" =~ ^[[:space:]]*[0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]*$ ]]; then
        # Drop the trailing empty stamp (and blank lines after it)
        local tmp
        tmp="$(mktemp)"
        awk -v last="$last" '{ lines[NR] = $0 } END {
            n = NR
            while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--
            if (n > 0 && lines[n] == last) n--
            while (n > 0 && lines[n] ~ /^[[:space:]]*$/) n--
            for (i = 1; i <= n; i++) print lines[i]
        }' "$NOTE_FILE" > "$tmp" && cat "$tmp" > "$NOTE_FILE"
        rm -f "$tmp"
    fi
    printf '\n%s\n' "$TIME" >> "$NOTE_FILE"
}

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
        stamp_note
        exec nvim "${NVIM_ARGS[@]}" -c "normal! GA" -c "startinsert" "$NOTE_FILE"
    else
        exec nvim "${NVIM_ARGS[@]}" "$NOTE_FILE"
    fi
else
    # Original single-buffer behavior
    if [[ $VIEW_ONLY -eq 0 ]]; then
        stamp_note
        exec nvim +"normal! GA" +"startinsert" "$NOTE_FILE"
    else
        exec nvim "$NOTE_FILE"
    fi
fi