#!/usr/bin/env bash
# Install the vendor-trailer strip hook so Cursor/Claude/Grok cannot
# paint themselves onto GitHub as contributors. Skippy-Agent is kept.
#
# Repos under these roots get the hook (one level deep):
#   ~/GitHub, $PIERCINGXX_WORK_ROOT/GitHub and its project folders.
# Override with GIT_HOOK_ROOTS="/path/one:/path/two".
# An existing, different commit-msg hook is backed up to commit-msg.bak-<date>.
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
HOOK_SRC="$ROOT/.githooks/commit-msg"
[ -f "$HOOK_SRC" ] || { echo "missing $HOOK_SRC" >&2; exit 1; }

# Always the invoking user's real home (plain `sudo` keeps HOME=/root otherwise)
username="$(id -un)"
home_dir="$(getent passwd "$username" | cut -d: -f6)"
[ -n "$home_dir" ] || home_dir="$HOME"
work_root="${PIERCINGXX_WORK_ROOT:-/media/Working-Storage}"
stamp="$(date +%Y%m%d-%H%M%S)"

# install_hook DEST : copy the hook, backing up a different existing one
install_hook() {
    local dest="$1"
    mkdir -p "$(dirname "$dest")"
    if [ -e "$dest" ] && ! cmp -s "$HOOK_SRC" "$dest"; then
        if [ "$(readlink -f "$HOOK_SRC")" = "$(readlink -f "$dest")" ]; then
            return 0
        fi
        cp -a "$dest" "$dest.bak-$stamp"
        echo "Backed up existing hook: $dest.bak-$stamp"
    fi
    cmp -s "$HOOK_SRC" "$dest" 2>/dev/null || install -m 755 "$HOOK_SRC" "$dest"
}

template_dir="$home_dir/.config/git/templates"
template_hook="$template_dir/hooks/commit-msg"

install_hook "$template_hook"

current_template="$(git config --global --get init.templateDir || true)"
if [ -z "$current_template" ]; then
    git config --global init.templateDir "$template_dir"
    echo "Set init.templateDir to $template_dir"
elif [ "$current_template" != "$template_dir" ]; then
    install_hook "$current_template/hooks/commit-msg"
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
        install_hook "$dest/commit-msg"
    else
        local gitdir
        gitdir="$(git -C "$repo" rev-parse --git-dir)"
        case "$gitdir" in
            /*) ;;
            *) gitdir="$repo/$gitdir" ;;
        esac
        install_hook "$gitdir/hooks/commit-msg"
    fi
}

# This repo: use the committed .githooks path.
if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$ROOT" config core.hooksPath .githooks
    chmod +x "$HOOK_SRC"
    echo "Enabled .githooks for piercing-dots"
fi

# Existing clones under the usual GitHub work roots: each root, its repos,
# and project folders that group repos one level further down.
roots=()
if [ -n "${GIT_HOOK_ROOTS:-}" ]; then
    IFS=':' read -r -a roots <<< "$GIT_HOOK_ROOTS"
else
    roots=("$home_dir/GitHub" "$work_root/GitHub")
    for sub in "$work_root"/GitHub/*/; do
        sub="${sub%/}"
        [ -d "$sub/.git" ] && continue   # a repo, not a project folder
        roots+=("$sub")
    done
fi

for root in "${roots[@]}"
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
