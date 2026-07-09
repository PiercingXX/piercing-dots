#!/bin/bash

set -euo pipefail

THEME_NAME="Black-Minimalistic"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_THEME_DIR="$REPO_ROOT/resources/cursors/$THEME_NAME"
TARGETS=(
    "$HOME/.icons/$THEME_NAME"
    "$HOME/.local/share/icons/$THEME_NAME"
)

if [ ! -d "$SOURCE_THEME_DIR/cursors" ] || [ ! -f "$SOURCE_THEME_DIR/index.theme" ]; then
    echo "Error: vendored cursor theme is missing: $SOURCE_THEME_DIR"
    exit 1
fi

ensure_alias() {
    local cursor_dir="$1"
    local source_name="$2"
    shift 2

    local source_path=""
    for candidate in "$cursor_dir/$source_name" "$cursor_dir/$source_name.cur" "$cursor_dir/$source_name.ani"; do
        if [ -f "$candidate" ]; then
            source_path="$candidate"
            break
        fi
    done

    if [ -z "$source_path" ]; then
        echo "Warning: missing cursor source for aliases: $source_name"
        return 0
    fi

    local alias
    for alias in "$@"; do
        ln -sf "$(basename "$source_path")" "$cursor_dir/$alias"
    done
}

add_extended_aliases() {
    local theme_dir="$1"
    local cursor_dir="$theme_dir/cursors"

    ensure_alias "$cursor_dir" "Black Minimalistic - normal select" left_ptr default arrow top_left_arrow left-arrow
    ensure_alias "$cursor_dir" "Black Minimalistic - text select" xterm ibeam text vertical-text
    ensure_alias "$cursor_dir" "Black Minimalistic - working in background" left_ptr_watch progress
    ensure_alias "$cursor_dir" "Black Minimalistic - busy" watch wait
    ensure_alias "$cursor_dir" "Black Minimalistic - precision select" crosshair tcross cell
    ensure_alias "$cursor_dir" "Black Minimalistic - unavailable" not-allowed crossed_circle no-drop
    ensure_alias "$cursor_dir" "Black Minimalistic - horizontal resize" sb_h_double_arrow size_hor ew-resize col-resize e-resize w-resize
    ensure_alias "$cursor_dir" "Black Minimalistic - vertical resize" sb_v_double_arrow size_ver ns-resize row-resize n-resize s-resize
    ensure_alias "$cursor_dir" "Black Minimalistic - diagonal resize 1" size_bdiag nesw-resize ne-resize sw-resize
    ensure_alias "$cursor_dir" "Black Minimalistic - diagonal resize 2" size_fdiag nwse-resize nw-resize se-resize
    ensure_alias "$cursor_dir" "Black Minimalistic - move" fleur size_all all-scroll move
    ensure_alias "$cursor_dir" "Black Minimalistic - link select" hand2 pointer grab grabbing copy alias
}

create_default_inheritance() {
    local base_icons_dir="$1"
    local default_dir="$base_icons_dir/default"

    mkdir -p "$default_dir"
    cat > "$default_dir/index.theme" <<EOF
[Icon Theme]
Name=Default
Comment=Default cursor fallback
Inherits=$THEME_NAME
EOF
}

install_theme_target() {
    local target_theme_dir="$1"

    mkdir -p "$(dirname "$target_theme_dir")"
    rm -rf "$target_theme_dir"
    cp -a "$SOURCE_THEME_DIR" "$target_theme_dir"
    add_extended_aliases "$target_theme_dir"
    create_default_inheritance "$(dirname "$target_theme_dir")"
}

apply_flatpak_overrides() {
    if ! command -v flatpak >/dev/null 2>&1; then
        return 0
    fi

    # Let Flatpak apps read cursor themes from standard user icon locations.
    flatpak --user override --filesystem="$HOME/.icons:ro" --filesystem="$HOME/.local/share/icons:ro" || true

    local app
    for app in com.discordapp.Discord dev.vencord.Vesktop; do
        if flatpak --user info "$app" >/dev/null 2>&1; then
            flatpak --user override --filesystem="$HOME/.icons:ro" --filesystem="$HOME/.local/share/icons:ro" "$app" || true
        fi
    done
}

for target in "${TARGETS[@]}"; do
    install_theme_target "$target"
done

apply_flatpak_overrides

echo "Installed cursor theme from vendored assets: $THEME_NAME"
