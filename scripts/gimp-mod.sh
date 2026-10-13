#!/usr/bin/env bash
# GitHub.com/PiercingXX
# Replace the GIMP config (native + flatpak) with the piercing-dots one.
# The existing config is backed up first.

set -euo pipefail

script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
# shellcheck disable=SC1091
. "$script_dir/../resources/.scripts/lib/common.sh"

src="$script_dir/../dots/GIMP"
[ -d "$src" ] || die "GIMP dots not found at $src"

resolve_username() {
    if [ -n "${SUDO_USER:-}" ] && getent passwd "$SUDO_USER" >/dev/null 2>&1; then
        echo "$SUDO_USER"
        return
    fi
    id -un
}

username="$(resolve_username)"
home_dir="$(getent passwd "$username" | cut -d: -f6)"
[ -z "$home_dir" ] && home_dir="/home/$username"

targets=("$home_dir/.config/GIMP")
[ -d "$home_dir/.var/app/org.gimp.GIMP" ] && targets+=("$home_dir/.var/app/org.gimp.GIMP/config/GIMP")

confirm "Replace GIMP config for $username (current config is backed up)?" || { say "Cancelled."; exit 0; }

stamp=$(date +%Y%m%d-%H%M%S)
for dir in "${targets[@]}"; do
    if [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
        backup="${dir}.bak-$stamp"
        cp -a "$dir" "$backup"
        say "Backed up $dir -> $backup"
    fi
    # Copy into a staging dir first so a failed copy never leaves an empty config
    staging=$(mktemp -d "$(dirname "$dir")/.gimp-staging.XXXXXX" 2>/dev/null || mktemp -d)
    cp -R "$src"/. "$staging"/
    rm -rf "$dir"
    mkdir -p "$(dirname "$dir")"
    mv "$staging" "$dir"
    chmod 755 "$dir"
    chown -R "$username":"$(id -gn "$username")" "$dir"
    ok "Installed GIMP config -> $dir"
done
