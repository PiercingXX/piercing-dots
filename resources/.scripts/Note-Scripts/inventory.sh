#!/bin/bash
# GitHub.com/PiercingXX

INVENTORY_DIR="/media/Archived-Storage/[03] Other/My Life/05 Business/01 T/30 Inventory Stuffs"
YAZI_BIN="$(command -v yazi 2>/dev/null || true)"

if [[ -z "$YAZI_BIN" && -x "$HOME/.cargo/bin/yazi" ]]; then
	YAZI_BIN="$HOME/.cargo/bin/yazi"
fi

if [[ -z "$YAZI_BIN" ]]; then
	printf 'inventory.sh: yazi not found in PATH or at %s.\n' "$HOME/.cargo/bin/yazi" >&2
	exit 1
fi

if [[ -t 0 && -t 1 ]]; then
	exec "$YAZI_BIN" "$INVENTORY_DIR"
fi

if command -v kitty >/dev/null 2>&1; then
	exec kitty --title "Inventory" "$YAZI_BIN" "$INVENTORY_DIR"
fi

printf 'inventory.sh: yazi needs a terminal, and kitty is not available for fallback.\n' >&2
exit 1