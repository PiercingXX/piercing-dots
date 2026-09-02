#!/usr/bin/env bash
# Install the vendor-trailer strip hook so Cursor/Claude/Grok cannot
# paint themselves onto GitHub as contributors. Skippy-Agent is kept.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK_SRC="$ROOT/.githooks/commit-msg"
[ -f "$HOOK_SRC" ] || { echo "missing $HOOK_SRC" >&2; exit 1; }

username="$(id -un)"
home_dir="${HOME:-$(getent passwd "$username" | cut -d: -f6)}"
template_dir="$home_dir/.config/git/templates"
template_hook="$template_dir/hooks/commit-msg"

mkdir -p "$template_dir/hooks"
install -m 755 "$HOOK_SRC" "$template_hook"

current_template="$(git config --global --get init.templateDir || true)"
if [ -z "$current_template" ]; then
    git config --global init.templateDir "$template_dir"
    echo "Set init.templateDir to $template_dir"
elif [ "$current_template" != "$template_dir" ]; then
    mkdir -p "$current_template/hooks"
    install -m 755 "$HOOK_SRC" "$current_template/hooks/commit-msg"
    echo "Installed commit-msg into existing templateDir $current_template"
fi

install_into_repo() {
    local repo="$1"
    [ -d "$repo/.git" ] || [ -f "$repo/.git" ] || return 0
    local hp dest
    hp="$(git -C "$repo" config --get core.hooksPath || true)"
    if [ -n "$hp" ]; then
        case "$hp" in
            /*) dest="$hp" ;;
            *) dest="$repo/$hp" ;;
        esac
        mkdir -p "$dest"
        if [ "$(readlink -f "$HOOK_SRC")" != "$(readlink -f "$dest/commit-msg" 2>/dev/null || true)" ]; then
            install -m 755 "$HOOK_SRC" "$dest/commit-msg"
        fi
    else
        local gitdir
        gitdir="$(git -C "$repo" rev-parse --git-dir)"
        case "$gitdir" in
            /*) ;;
            *) gitdir="$repo/$gitdir" ;;
        esac
        mkdir -p "$gitdir/hooks"
        install -m 755 "$HOOK_SRC" "$gitdir/hooks/commit-msg"
    fi
}

# This repo: use the committed .githooks path.
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$ROOT" config core.hooksPath .githooks
    chmod +x "$HOOK_SRC"
    echo "Enabled .githooks for piercing-dots"
fi

# Existing clones under the usual GitHub work roots.
for root in \
    "$home_dir/GitHub" \
    /media/Working-Storage/GitHub \
    /media/Working-Storage/GitHub/Skippy-Project \
    /media/Working-Storage/GitHub/Battlezone-Projects \
    /media/Working-Storage/GitHub/Phone-Projects \
    /media/Working-Storage/GitHub/Linux-Mods \
    /media/Working-Storage/GitHub/xx-stack
do
    [ -d "$root" ] || continue
    if [ -d "$root/.git" ]; then
        install_into_repo "$root"
        continue
    fi
    for repo in "$root" "$root"/*; do
        [ -d "$repo" ] || continue
        install_into_repo "$repo" || true
    done
done

echo "Vendor trailer hook installed. Skippy-Agent is allowed; Cursor/Claude/Grok are not."
