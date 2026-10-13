#!/bin/bash
# GitHub.com/PiercingXX
# Open the inventory folder in yazi (keybinds launch this inside kitty).
# Folder lives under $PIERCINGXX_NOTES_ROOT (default: the Archived-Storage drive).

# shellcheck disable=SC1091
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

NOTES_ROOT="${PIERCINGXX_NOTES_ROOT:-$PX_ARCHIVE_ROOT/[03] Other/My Life}"
INVENTORY_DIR="$NOTES_ROOT/05 Business/01 T/30 Inventory Stuffs"

fail() {
	notify_replace inventory critical 6000 dialog-error "Inventory" "$1"
	printf 'inventory.sh: %s\n' "$1" >&2
	[[ -t 0 ]] && read -r -t 10 -p "Press Enter to close..." _
	exit 1
}

YAZI_BIN="$(command -v yazi 2>/dev/null || true)"
if [[ -z "$YAZI_BIN" && -x "$HOME/.cargo/bin/yazi" ]]; then
	YAZI_BIN="$HOME/.cargo/bin/yazi"
fi

[[ -n "$YAZI_BIN" ]] || fail "yazi not found in PATH or at $HOME/.cargo/bin/yazi."
[[ -d "$INVENTORY_DIR" ]] || fail "Inventory folder not found: $INVENTORY_DIR (drive not mounted? set PIERCINGXX_NOTES_ROOT)"

exec "$YAZI_BIN" "$INVENTORY_DIR"
